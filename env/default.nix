{
  pkgs,
  inputs,
  self,
}: let
  system = pkgs.stdenv.hostPlatform.system;

  tools = import ./packages.nix {inherit pkgs;};

  wrapped = [
    self.packages.${system}.helix
    self.packages.${system}.nh
    self.packages.${system}.opencode
  ];

  askpass = pkgs.writeShellScriptBin "wrapps-askpass" ''
    set -uo pipefail

    case "''${1:-}" in
      *"Confirm user presence"*)
        printf 'y\n'
        exit 0
        ;;
    esac

    exec ''${WRAPPS_PIN_DIALOG:?не указан диалог} "$@"
  '';

  sshconfig = pkgs.writeShellScriptBin "wrapps-ssh-config" ''
    set -uo pipefail

    cfg="$HOME/.ssh/config"
    marker="# wrapps: FIDO2-ключи"

    # Свой блок переписываем с нуля, а не «если нет»: ssh читает пользовательский
    # конфиг раньше системного, поэтому именно этот блок задаёт порядок
    # IdentityFile. Блок дописан в конец файла — вырезаем его целиком, иначе он
    # залипает навсегда (в том числе со старым порядком ключей).
    if [ -f "$cfg" ] && grep -qF "$marker" "$cfg"; then
      tmp="$cfg.wrapps.$$"
      awk '
        /^# wrapps: FIDO2-ключи$/ { drop=1; next }
        drop && (/^#/ || /^Host \*$/ || /^  IdentitiesOnly / || /^  IdentityFile /) { next }
        drop { drop=0 }
        { print }
      ' "$cfg" >"$tmp" && cat "$tmp" >"$cfg" && rm -f "$tmp"
    fi

    # ssh складывает IdentityFile из системного и пользовательского конфигов,
    # а не перезаписывает. Если sk-ключи уже перечислены системой, свой блок
    # не нужен — иначе каждый ключ попадёт в перебор дважды. Проверяем файл
    # напрямую: ssh -G -F /dev/null отбрасывает и системный конфиг, поэтому
    # через него это не видно.
    if [ -r /etc/ssh/ssh_config ] && grep -qE '^[[:space:]]*IdentityFile.*(_sk|id_ecdsa_sk|id_ed25519_sk)' /etc/ssh/ssh_config; then
      printf 'системный ssh_config уже перечисляет sk-ключи — блок в %s убран\n' "$cfg" >&2
      exit 0
    fi

    # Порядок важен: ssh идёт по IdentityFile слева направо и спотыкается на
    # первом же токене, которого нет под рукой. @clone — тот, что всегда с
    # собой, поэтому его ключи кладём раньше @alone.
    keys=""
    for want in clone other; do
      for k in "$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*; do
        case "$k" in *.pub) continue ;; esac
        [ -f "$k" ] || continue
        case "$k" in
          *@clone) [ "$want" = clone ] || continue ;;
          *) [ "$want" = other ] || continue ;;
        esac
        keys="$keys\n  IdentityFile $k"
      done
    done
    if [ -z "$keys" ]; then
      printf 'sk-ключей в ~/.ssh нет: cd ~/.ssh && ssh-keygen -K\n' >&2
      exit 1
    fi

    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    printf '\n%s\n# Ключи с именами FIDO2-токенов ssh не угадывает: в списке\n# IdentityFile по умолчанию есть только id_ecdsa_sk.\nHost *\n  IdentitiesOnly yes%b\n' \
      "$marker" "$keys" >>"$cfg"

    chmod 600 "$cfg"
    printf 'добавлен блок для FIDO2-ключей в %s\n' "$cfg" >&2

    effective="$(ssh -G -F "$cfg" github.com 2>/dev/null | awk '/^identitiesonly /{print $2; exit}')"
    if [ "$effective" != "yes" ]; then
      printf 'ВНИМАНИЕ: IdentitiesOnly не применился (effective=%s).\n' "$effective" >&2
      printf 'Выше в %s есть другой блок с IdentitiesOnly — он имеет приоритет.\n' "$cfg" >&2
      printf 'Ключи добавлены, но ssh будет перебирать весь агент.\n' >&2
    fi
  '';

  agent = pkgs.writeShellScriptBin "wrapps-agent" ''
    set -uo pipefail

    if [ -n "''${WAYLAND_DISPLAY:-''${DISPLAY:-}}" ]; then
      dialog=${pkgs.openssh-askpass}/libexec/gtk-ssh-askpass
    else
      dialog=""
    fi

    case "$dialog" in
      "") dialog_kind="нет окна PIN" ;;
      *) dialog_kind="окно PIN" ;;
    esac

    sock="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wrapps-agent.sock"
    mkdir -p "$(dirname "$sock")"
    pidfile="$sock.pid"

    # Порядок ключей в агенте — это и есть порядок, в котором ssh предлагает
    # ключи серверу: ключи из агента идут раньше файловых и в порядке агента
    # (sshconnect2.c, agent_keys), поэтому IdentityFile в ssh_config здесь
    # ничего не решает. @clone — тот, что всегда с собой, поэтому первым: иначе
    # ssh первым предлагает @alone и тратит PIN и касание на ключ, которого рядом
    # нет. Тот же порядок задаёт wrapps-ssh-config для случая без агента.
    keys=""
    for want in clone other; do
      for k in "$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*; do
        case "$k" in *.pub) continue ;; esac
        [ -f "$k" ] || continue
        case "$k" in
          *@clone) [ "$want" = clone ] || continue ;;
          *) [ "$want" = other ] || continue ;;
        esac
        keys="$keys $k"
      done
    done

    why=""
    usable() {
      local pid cmd want
      [ -S "$sock" ] || return 1
      [ -f "$pidfile" ] || { why="нет pidfile"; return 1; }
      IFS= read -r pid <"$pidfile" || { why="pidfile не читается"; return 1; }
      [ -n "$pid" ] || { why="в pidfile нет pid"; return 1; }
      kill -0 "$pid" 2>/dev/null || { why="агент pid=$pid не отвечает"; return 1; }
      cmd="$(tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null || true)"
      case "$cmd" in
        ssh-agent*" -a $sock"*) ;;
        *) why="pid=$pid занят не агентом (cmdline: ''${cmd:-пусто})"; return 1 ;;
      esac
      want="$(sed -n '2p' "$pidfile" 2>/dev/null || true)"
      if [ "$want" != "$dialog_kind" ]; then
        why="диалог не тот (в pidfile: ''${want:-пусто}, сейчас: $dialog_kind)"
        return 1
      fi
      # Порядок ключей — тоже часть агента, а не украшение: агент, поднятый
      # старым скриптом, останется с прежним порядком до перезапуска, и это
      # молчаливая поломка (лишний PIN и касание на каждом push). Поэтому
      # сохранённый список сравниваем так же, как вид диалога.
      want="$(sed -n '3p' "$pidfile" 2>/dev/null || true)"
      if [ "$want" != "$keys" ]; then
        why="порядок ключей в агенте не тот (в pidfile: ''${want:-пусто})"
        return 1
      fi
      return 0
    }

    if ! usable; then
      if [ -S "$sock" ]; then
        SSH_AUTH_SOCK="$sock" ssh-agent -k >/dev/null 2>&1 || true
        echo "старый агент на $sock снят: ''${why}" >&2
      fi
      rm -f "$sock" "$pidfile"

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
      printf '%s\n%s\n%s\n' "$pid" "$dialog_kind" "$keys" >"$pidfile"
    fi

    export SSH_AUTH_SOCK="$sock"

    ssh-add -l >/dev/null 2>&1 || [ $? -eq 1 ] || {
      echo "агент на $sock не отвечает" >&2
      exit 1
    }

    # $keys без кавычек намеренно: это список путей, разделённых пробелом, и
    # пробелов внутри самих путей не бывает (имена ключей — из ssh-keygen -K).
    for k in $keys; do
      ssh-add "$k" >/dev/null 2>&1 || true
    done

    if [ -n "$dialog" ]; then
      echo "export SSH_ASKPASS=${askpass}/bin/wrapps-askpass"
      echo "export SSH_ASKPASS_REQUIRE=force"
      echo "export WRAPPS_PIN_DIALOG=$dialog"
    fi
    echo "export SSH_AUTH_SOCK=$sock"
  '';

  # Конфиг atuin кладём в store: atuin читает его из ATUIN_CONFIG_DIR
  # (см. envrc), а ~/.config/atuin не в пресетах preservation и откатывается
  # вместе с корнем, поэтому в home ему жить незачем. Источник правды —
  # atuin.toml.
  atuinConfig = pkgs.writeTextDir "config.toml" (builtins.readFile ./atuin.toml);

  envrc = pkgs.writeText "envrc" ''
    # Переменные хоста из harness: HARNESS_DIR, PKM_VAULT и адреса локальных
    # моделей для opencode.json ({env:LOCAL_MAIN_URL}/{env:LOCAL_FAST_URL}).
    # Канонический файл ставит install.sh harness (симлинк на hosts/<host>.env);
    # если его нет — молча пропускаем, среда остаётся рабочей без локальных
    # моделей. Место подгрузки выбрано по harness/README.md: инициализация
    # оболочки у нас — этот rcfile, а не ~/.bashrc.
    if [ -r "$HOME/.config/harness.env" ]; then
      set -a
      . "$HOME/.config/harness.env"
      set +a
    fi

    # atuin в bash работает только через интерфейс bash-preexec: сам init лишь
    # дописывает __atuin_preexec/__atuin_precmd в preexec_functions и
    # precmd_functions, а вызывает их bash-preexec. Без него ATUIN_HISTORY_ID
    # остаётся пустым (ATUIN_PREEXEC_BACKEND=<shlvl>:none), __atuin_precmd
    # выходит на первой же строке, и история не пишется вовсе. Тот же пробел у
    # NixOS-модуля programs.atuin — он тоже просто делает atuin init.
    source ${pkgs.bash-preexec}/share/bash/bash-preexec.sh

    # starship идёт после bash-preexec: увидев __bp_imported, он регистрируется
    # через precmd_functions, а не перетирает PROMPT_COMMAND.
    eval "$(${pkgs.starship}/bin/starship init bash)"

    export ATUIN_CONFIG_DIR=${atuinConfig}

    eval "$(${pkgs.atuin}/bin/atuin init bash --disable-up-arrow)"

    _have_key=0
    for _k in "$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*; do
      case "$_k" in *.pub) continue ;; esac
      [ -f "$_k" ] && { _have_key=1; break; }
    done
    _have_fido=0
    grep -lqiE 'HID_NAME=.*FIDO' /sys/class/hidraw/hidraw*/device/uevent 2>/dev/null && _have_fido=1

    # Хост объявляет свой агент раньше нас: NixOS `programs.ssh.startAgent`
    # кладёт `SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-agent` в `set-environment`, то
    # есть во все процессы сессии, а ключи FIDO2 грузит только `wrapps-agent`.
    # Две щели, в которые это выходит боком, говорим вслух: ключей с токена в
    # ~/.ssh ещё нет (терминал, открытый до `ssh-keygen -K`, останется с чужим
    # пустым агентом навсегда — env уже унаследован), и агент не поднялся, так
    # что сокет остался чужим. Симптом у обоих один: push отвечает
    # «Permission denied (publickey)», что читается как «доступа нет».
    _sock="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wrapps-agent.sock"
    if [ "$_have_key" = 1 ] && [ "$_have_fido" = 1 ]; then
      eval "$(${agent}/bin/wrapps-agent)"
      ${sshconfig}/bin/wrapps-ssh-config >/dev/null 2>&1 || true
      if [ "''${SSH_AUTH_SOCK:-}" != "$_sock" ]; then
        printf 'env: SSH_AUTH_SOCK=%s, а ключи FIDO2 лежат в %s\n' "''${SSH_AUTH_SOCK:-пусто}" "$_sock" >&2
        printf 'env: пустой агент ответит «Permission denied (publickey)» — поправить: eval "$(wrapps-agent)"\n' >&2
      fi
    elif [ "$_have_fido" = 1 ]; then
      printf 'env: sk-ключей в ~/.ssh нет — они на токене: cd ~/.ssh && ssh-keygen -K\n' >&2
    fi
    unset _sock

    _fzf_theme="''${XDG_CONFIG_HOME:-$HOME/.config}/fzf/themes/noctalia.sh"
    if [ -f "$_fzf_theme" ]; then
      . "$_fzf_theme"
    fi
    unset _fzf_theme
  '';

  deployConfig = target: content: ''
    if [ ! -f "${target}" ]; then
      mkdir -p "$(dirname "${target}")"
      if ! install -m 644 ${content} "${target}"; then
        printf 'env: не удалось положить %s\n' "${target}" >&2
      fi
    fi
  '';

  denv = pkgs.writeShellScriptBin "denv" ''
    export SHELL="${pkgs.bash}/bin/bash"
    export EDITOR="${self.packages.${system}.helix}/bin/hx"
    export PATH="${pkgs.lib.makeBinPath (tools ++ wrapped)}:$PATH"

    ${deployConfig "\${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml" ./starship.toml}

    ${deployConfig "\${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc" ./fastfetch/config.jsonc}

    ${deployConfig "\${XDG_CONFIG_HOME:-$HOME/.config}/btop/btop.conf" ./btop.conf}

    ${deployConfig "\${HOME}/.tmux.conf" ./tmux.conf}

    exec ${pkgs.bash}/bin/bash --rcfile ${envrc} "$@"
  '';

  shell = pkgs.writeShellScriptBin "shell" ''
    exec ${denv}/bin/denv "$@"
  '';
in
  pkgs.symlinkJoin {
    name = "env";
    paths = tools ++ wrapped ++ [denv shell agent askpass sshconfig];
    meta.mainProgram = "denv";
  }
