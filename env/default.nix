{ pkgs, inputs, self }:
let
  system = pkgs.stdenv.hostPlatform.system;

  tools = import ./packages.nix { inherit pkgs; };

  wrapped = [
    self.packages.${system}.helix
    self.packages.${system}.zellij
    self.packages.${system}.nh
  ];

  # Диалог PIN: отвечает агенту ровно тем, что ввёл человек.
  #
  # Своего счётчика попыток здесь нет и быть не должно. Скрипт получает строку
  # и отдаёт её, а верный PIN или нет — вопрос токена, и узнать это отсюда
  # нельзя. Счётчик запросов считал бы и успешные, отказывая после трёх
  # нормальных подписей, то есть давал бы ложную защиту вместо настоящей.
  # Остаток попыток виден только в меню самого токена; читать его программно
  # нечем — fido2-token -L показывает вендора и продукт, ykman этот токен не
  # видит.
  askpass = pkgs.writeShellScriptBin "wrapps-askpass" ''
    set -uo pipefail

    # Агент задаёт два вопроса: подтверждение присутствия и PIN. На первый
    # отвечаем сами: настоящая проверка — касание токена, его нельзя ни
    # пропустить, ни подделать, а лишнее окно только мешает.
    case "''${1:-}" in
      *"Confirm user presence"*)
        printf 'y\n'
        exit 0
        ;;
    esac

    exec ''${WRAPPS_PIN_DIALOG:?не указан диалог} "$@"
  '';

  # Блок в ~/.ssh/config для хостов, где нет /etc/ssh/ssh_config из NixOS:
  # live ISO и чужие машины. Нужен потому, что ssh не угадывает имена ключей с
  # FIDO2-токенов: в списке IdentityFile по умолчанию есть только `id_ecdsa_sk`,
  # а файл называется `id_ecdsa_sk_rk_solo@clone`. Без блока серверу не
  # предлагается ничего и ssh уходит в пароль.
  #
  # На NixOS-хостах тот же блок лежит в /etc/ssh/ssh_config (infra,
  # modules/services/git.nix) и этот скрипт там ничего не меняет: его блок
  # отличается маркером, а чужой конфиг только дополняется.
  sshconfig = pkgs.writeShellScriptBin "wrapps-ssh-config" ''
    set -uo pipefail

    cfg="$HOME/.ssh/config"
    marker="# wrapps: FIDO2-ключи"

    # Свой блок не трогаем никогда, чужой конфиг — только дополняем.
    if [ -f "$cfg" ] && grep -qF "$marker" "$cfg"; then
      exit 0
    fi

    keys=""
    for k in "$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*; do
      case "$k" in *.pub) continue ;; esac
      [ -f "$k" ] || continue
      keys="$keys\n  IdentityFile $k"
    done
    if [ -z "$keys" ]; then
      printf 'sk-ключей в ~/.ssh нет: cd ~/.ssh && ssh-keygen -K\n' >&2
      exit 1
    fi

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # IdentitiesOnly снимает поиск по агенту: иначе ssh перебирает всё, что
    # там лежит, и предлагает серверу лишние токены.
    printf '\n%s\n# Ключи с именами FIDO2-токенов ssh не угадывает: в списке\n# IdentityFile по умолчанию есть только id_ecdsa_sk.\nHost *\n  IdentitiesOnly yes%b\n' \
      "$marker" "$keys" >>"$cfg"

    chmod 600 "$cfg"
    printf 'добавлен блок для FIDO2-ключей в %s\n' "$cfg" >&2
  '';

  # Подъём агента. Вызывается как `eval "$(wrapps-agent)"`, поэтому в stdout
  # идут только строки для eval, всё остальное — в stderr.
  agent = pkgs.writeShellScriptBin "wrapps-agent" ''
    set -uo pipefail

    # Диалог нужен там, где у агента нет терминала, — в графической сессии.
    # На консоли live ISO терминал есть, агент спрашивает сам, и поднимать
    # окно там нечем. Поэтому без дисплея SSH_ASKPASS не задаётся вовсе.
    if [ -n "''${WAYLAND_DISPLAY:-''${DISPLAY:-}}" ]; then
      # openssh-askpass, а не pinentry: pinentry говорит с gpg-агентом по
      # протоколу Assuan и в роли askpass зависает.
      dialog=${pkgs.openssh-askpass}/libexec/gtk-ssh-askpass
    else
      dialog=""
    fi

    sock="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wrapps-agent.sock"
    mkdir -p "$(dirname "$sock")"
    pidfile="$sock.pid"

    # Переиспользовать агент можно только если он наш, жив и поднят с тем же
    # диалогом. Последнее — не педантизм: агент наследует SSH_ASKPASS при
    # старте и больше переменную не читает, поэтому агент, поднятый без неё,
    # жив, держит ключи и всё выглядит исправно, но подписывать не умеет.
    # Сверять pid и сокет недостаточно: сокет тот же, условия разные.
    usable() {
      local pid cmd want
      # Сокет проверяется первым: его можно убить снаружи, а pid-файл и процесс
      # останутся, и агент без сокета объявит себя рабочим — подпись и push
      # после этого не идут, а ssh-add -l на таком агенте молчит.
      [ -S "$sock" ] || return 1
      [ -f "$pidfile" ] || return 1
      IFS= read -r pid <"$pidfile" || return 1
      [ -n "$pid" ] || return 1
      kill -0 "$pid" 2>/dev/null || return 1
      cmd="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)"
      case "$cmd" in
        ssh-agent*" -a $sock"*) ;;
        *) return 1 ;;
      esac
      want="$(sed -n '2p' "$pidfile" 2>/dev/null || true)"
      [ "$want" = "$dialog" ] || return 1
      return 0
    }

    if ! usable; then
      if [ -S "$sock" ]; then
        SSH_AUTH_SOCK="$sock" ssh-agent -k >/dev/null 2>&1 || true
        echo "старый агент на $sock снят: он поднят с другим диалогом" >&2
      fi
      rm -f "$sock" "$pidfile"

      # Вывод `ssh-agent -a SOCK` — строки `VAR=VALUE; export VAR;` плюс
      # `echo Agent pid N;`. Последнюю не выполняем: она ушла бы в stdout и
      # сломала бы eval у вызывающего. PID берём из SSH_AGENT_PID.
      out="$(SSH_ASKPASS="$dialog" \
             SSH_ASKPASS_REQUIRE="''${dialog:+force}" \
             WRAPPS_PIN_DIALOG="$dialog" \
               ssh-agent -a "$sock")"
      pid="$(printf '%s\n' "$out" | sed -n 's/^SSH_AGENT_PID=\([^;]*\);.*/\1/p' | head -n1)"
      got="$(printf '%s\n' "$out" | sed -n 's/^SSH_AUTH_SOCK=\([^;]*\);.*/\1/p' | head -n1)"
      if [ -z "$pid" ] || [ "$got" != "$sock" ]; then
        echo "не удалось поднять агента: $out" >&2
        exit 1
      fi
      printf '%s\n%s\n' "$pid" "$dialog" >"$pidfile"
    fi

    # Дальше ssh-add должен обращаться к агенту, которого мы только что
    # подняли, а не к унаследованному от вызывающего, иначе проверка живости
    # и автозагрузка ключа работают с чужим агентом.
    export SSH_AUTH_SOCK="$sock"

    # rc=0 — ключи есть, rc=1 — агент жив и пуст, rc=2 — агента нет.
    ssh-add -l >/dev/null 2>&1 || [ $? -eq 1 ] || {
      echo "агент на $sock не отвечает" >&2
      exit 1
    }

    # Ключ в агент — здесь, а не на стороне вызывающего. Без этого ssh не
    # знает, какой ключ предлагать, и на чужом хосте уходит в пароль.
    if ! ssh-add -l 2>/dev/null | grep -qE 'ECDSA-SK|ED25519-SK'; then
      for k in "$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*; do
        case "$k" in *.pub) continue ;; esac
        if [ -f "$k" ]; then
          # Один ssh-add — один запрос PIN, и оба токена не нужны: хост идёт
          # по ~/.ssh/config с IdentitiesOnly и одним IdentityFile.
          ssh-add "$k" >/dev/null 2>&1 || true
          break
        fi
      done
    fi

    if [ -n "$dialog" ]; then
      echo "export SSH_ASKPASS=${askpass}/bin/wrapps-askpass"
      echo "export SSH_ASKPASS_REQUIRE=force"
      echo "export WRAPPS_PIN_DIALOG=$dialog"
    fi
    echo "export SSH_AUTH_SOCK=$sock"
  '';

  envrc = pkgs.writeText "envrc" ''
    # Промпт и история: темы приходят из noctalia (палитра/настройки в ~/.config),
    # без noctalia — дефолтный вид.
    eval "$(${pkgs.starship}/bin/starship init bash)"

    # atuin: история; стрелка-вверх остаётся за bash, чтобы не выгрызать нативы.
    eval "$(${pkgs.atuin}/bin/atuin init bash --disable-up-arrow)"

    # Агент для FIDO2-ключей поднимается, только если ключи физически есть и
    # токен в системе: на live ISO и на чужом хосте ~/.ssh может приехать из
    # контракта сохранения вместе с handle'ами, и поднимать там агент для
    # GitHub никто не просил.
    _have_key=0
    for _k in "$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*; do
      case "$_k" in *.pub) continue ;; esac
      [ -f "$_k" ] && { _have_key=1; break; }
    done
    _have_fido=0
    grep -lqiE 'HID_NAME=.*FIDO' /sys/class/hidraw/hidraw*/device/uevent 2>/dev/null && _have_fido=1

    if [ "$_have_key" = 1 ] && [ "$_have_fido" = 1 ]; then
      eval "$(${agent}/bin/wrapps-agent)"
      ${sshconfig}/bin/wrapps-ssh-config >/dev/null 2>&1 || true
    fi

    # sops/age: стандартные пути, чтобы правился ~/.config/sops.
    export SOPS_AGE_KEY_FILE="''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
  '';

  denv = pkgs.writeShellScriptBin "denv" ''
    export SHELL="${pkgs.bash}/bin/bash"
    export EDITOR="${self.packages.${system}.helix}/bin/hx"
    export PATH="${pkgs.lib.makeBinPath (tools ++ wrapped)}:$PATH"
    exec ${pkgs.bash}/bin/bash --rcfile ${envrc} "$@"
  '';

  shell = pkgs.writeShellScriptBin "shell" ''
    exec ${denv}/bin/denv "$@"
  '';
in
pkgs.symlinkJoin {
  name = "env";
  paths = tools ++ wrapped ++ [ denv shell agent askpass sshconfig ];
  meta.mainProgram = "denv";
}
