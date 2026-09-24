{ pkgs, inputs, self }:
let
  system = pkgs.stdenv.hostPlatform.system;

  tools = import ./packages.nix { inherit pkgs; };

  wrapped = [
    self.packages.${system}.helix
    self.packages.${system}.zellij
    self.packages.${system}.nh
  ];

  envrc = pkgs.writeText "envrc" ''
    # Промпт и история: темы приходят из noctalia (палитра/настройки в ~/.config),
    # без noctalia — дефолтный вид.
    eval "$(${pkgs.starship}/bin/starship init bash)"

    # atuin: история; стрелка-вверх остаётся за bash, чтобы не выгрызать нейтивы.
    eval "$(${pkgs.atuin}/bin/atuin init bash --disable-up-arrow)"

    # ssh-agent: gcr/gnome-keyring не умеет security-ключи (sk), поэтому свой сокет.
    if [ ! -S "$HOME/.ssh/socket" ]; then
      mkdir -p "$HOME/.ssh"
      ssh-agent -a "$HOME/.ssh/socket" >/dev/null 2>&1
    fi
    if [ -S "$HOME/.ssh/socket" ]; then
      export SSH_AUTH_SOCK="$HOME/.ssh/socket"

      # Ключи из токена: восстановить и загрузить в агент (PIN спросит один раз).
      keys() {
        local k
        for k in "$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*; do
          [ -f "$k" ] || continue
          case "$k" in *.pub) continue ;; esac
          ssh-add "$k" 2>/dev/null && return 0
        done
        echo "sk-ключей в ~/.ssh нет: ssh-keygen -K -w ~/.ssh" >&2
        return 1
      }
      ssh-add -l >/dev/null 2>&1 || keys || true
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
  paths = tools ++ wrapped ++ [ denv shell ];
  meta.mainProgram = "denv";
}