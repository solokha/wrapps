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
      # Загружаются ВСЕ найденные: порядок имён не должен решать, какой ключ
      # уедет в GitHub. Лишних касаний это не добавляет — ssh сначала проверяет
      # публичный ключ без подписи, и непринятый ключ отбрасывается без касания.
      # WRAPPS_SK_KEY=~/.ssh/ключ — загрузить только этот.
      keys() {
        local k loaded=
        local -a cands=()
        if [ -n "''${WRAPPS_SK_KEY:-}" ]; then
          cands+=("$WRAPPS_SK_KEY")
        else
          cands+=("$HOME"/.ssh/id_ecdsa_sk* "$HOME"/.ssh/id_ed25519_sk*)
        fi
        for k in "''${cands[@]}"; do
          case "$k" in *.pub) continue ;; esac
          [ -f "$k" ] || continue
          ssh-add "$k" 2>/dev/null && loaded="$loaded $k"
        done
        if [ -z "$loaded" ]; then
          echo "sk-ключей в ~/.ssh нет: cd ~/.ssh && ssh-keygen -K" >&2
          return 1
        fi
        echo "sk-ключи в агенте:$loaded" >&2
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