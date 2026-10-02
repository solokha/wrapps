{ pkgs, inputs, self }:
let
  system = pkgs.stdenv.hostPlatform.system;

  tools = import ./packages.nix { inherit pkgs; };

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
  '';

  agent = pkgs.writeShellScriptBin "wrapps-agent" ''
    set -uo pipefail

    if [ -n "''${WAYLAND_DISPLAY:-''${DISPLAY:-}}" ]; then
      dialog=${pkgs.openssh-askpass}/libexec/gtk-ssh-askpass
    else
      dialog=""
    fi

    sock="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/wrapps-agent.sock"
    mkdir -p "$(dirname "$sock")"
    pidfile="$sock.pid"

    usable() {
      local pid cmd want
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
