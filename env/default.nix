{
  pkgs,
  inputs,
  self,
}: let
  system = pkgs.stdenv.hostPlatform.system;

  tools = import ./packages.nix {inherit pkgs;};

  wrapped = [
    self.packages.${system}.opencode
    self.packages.${system}.atuin
    self.packages.${system}.btop
    self.packages.${system}.starship
    self.packages.${system}.tmux
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
      tmp="$cfg.wrapps.$$"
      awk '
        /^# wrapps: FIDO2-ключи$/ { drop=1; next }
        drop && (/^#/ || /^Host \*$/ || /^  IdentitiesOnly / || /^  IdentityFile /) { next }
        drop { drop=0 }
        { print }
      ' "$cfg" >"$tmp" && cat "$tmp" >"$cfg" && rm -f "$tmp"
    fi

    if [ -r /etc/ssh/ssh_config ] && grep -qE '^[[:space:]]*IdentityFile.*(_sk|id_ecdsa_sk|id_ed25519_sk)' /etc/ssh/ssh_config; then
      printf 'системный ssh_config уже перечисляет sk-ключи — блок в %s убран\n' "$cfg" >&2
      exit 0
    fi

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

  envrc = pkgs.writeText "envrc" ''
    if [ -r "$HOME/.config/harness.env" ]; then
      set -a
      . "$HOME/.config/harness.env"
      set +a
    fi

    source ${pkgs.bash-preexec}/share/bash/bash-preexec.sh

    eval "$(${self.packages.${system}.starship}/bin/starship init bash)"

    eval "$(${self.packages.${system}.atuin}/bin/atuin init bash --disable-up-arrow)"

    _have_key=0
    for _k in "$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*; do
      case "$_k" in *.pub) continue ;; esac
      [ -f "$_k" ] && { _have_key=1; break; }
    done
    _have_fido=0
    grep -lqiE 'HID_NAME=.*FIDO' /sys/class/hidraw/hidraw*/device/uevent 2>/dev/null && _have_fido=1

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

    if command -v direnv >/dev/null 2>&1; then
      eval "$(direnv hook bash)"
    fi

    _fzf_theme="''${XDG_CONFIG_HOME:-$HOME/.config}/fzf/themes/noctalia.sh"
    if [ -f "$_fzf_theme" ]; then
      . "$_fzf_theme"
    fi
    unset _fzf_theme
  '';

  denv = pkgs.writeShellScriptBin "denv" ''
    export SHELL="${pkgs.bash}/bin/bash"
    export EDITOR="${pkgs.micro}/bin/micro"
    export PATH="${pkgs.lib.makeBinPath (wrapped ++ tools)}:$PATH"

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
