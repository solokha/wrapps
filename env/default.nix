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

    # В pidfile кладём признак, а не путь к диалогу. Путь — store-путь, он
    # меняется при каждом обновлении nixpkgs и различается между сборками
    # wrapps, поэтому агент из старой сборки сравнивал его со своим и решал,
    # что диалог «другой», пересоздавая живой агент на ровном месте. Для
    # ssh-agent важно только одно: умеет ли он спросить PIN в окне.
    case "$dialog" in
      "") dialog_kind="нет окна PIN" ;;
      *) dialog_kind="окно PIN" ;;
    esac

    sock="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wrapps-agent.sock"
    mkdir -p "$(dirname "$sock")"
    pidfile="$sock.pid"

    # usable() возвращает 1 и записывает причину в $why. Причин четыре, и
    # раньше сообщение подставляло одну из них на все случаи — из-за этого
    # негодный агент выдавался за «поднят с другим диалогом».
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
      printf '%s\n%s\n' "$pid" "$dialog_kind" >"$pidfile"
    fi

    export SSH_AUTH_SOCK="$sock"

    ssh-add -l >/dev/null 2>&1 || [ $? -eq 1 ] || {
      echo "агент на $sock не отвечает" >&2
      exit 1
    }

    for k in "$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*; do
      case "$k" in *.pub) continue ;; esac
      [ -f "$k" ] || continue
      ssh-add "$k" >/dev/null 2>&1 || true
    done

    if [ -n "$dialog" ]; then
      echo "export SSH_ASKPASS=${askpass}/bin/wrapps-askpass"
      echo "export SSH_ASKPASS_REQUIRE=force"
      echo "export WRAPPS_PIN_DIALOG=$dialog"
    fi
    echo "export SSH_AUTH_SOCK=$sock"
  '';

  envrc = pkgs.writeText "envrc" ''
    eval "$(${pkgs.starship}/bin/starship init bash)"

    eval "$(${pkgs.atuin}/bin/atuin init bash --disable-up-arrow)"

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

    # Тема fzf от noctalia — это набор --color в FZF_DEFAULT_OPTS, файл
    # нужно подключить в шелл. Обёртка тут не нужна: у fzf нет ни конфига
    # по фиксированному пути, ни режима без переменных, всё решает env.
    _fzf_theme="''${XDG_CONFIG_HOME:-$HOME/.config}/fzf/themes/noctalia.sh"
    if [ -f "$_fzf_theme" ]; then
      # shellcheck source=/dev/null
      . "$_fzf_theme"
    fi
    unset _fzf_theme

    export SOPS_AGE_KEY_FILE="''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
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

    # starship: файл обязан лежать в ~/.config/starship.toml, это его путь по
    # умолчанию. noctalia потом дописывает в него свою палитру по маркерам,
    # поэтому он и создаётся здесь, а не обёрткой.
    ${deployConfig "\${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml" ./starship.toml}

    # fastfetch: тот же путь по умолчанию. Шаблон noctalia сливает цвета в
    # этот файл через jq, поэтому он обязан быть строгим JSON без комментариев
    # — в нём их нет специально.
    ${deployConfig "\${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch/config.jsonc" ./fastfetch/config.jsonc}

    # btop и tmux: noctalia правит существующие конфиги, а не создаёт их — без
    # файла её apply.sh падает с «config not found», и тема остаётся
    # непрочитанной. Файлы создаём мы, по правилу «если нет»; дальше в каждом
    # noctalia владеет ровно одной строкой.
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
