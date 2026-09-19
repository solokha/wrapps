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
  '';

  env = pkgs.writeShellScriptBin "env" ''
    export SHELL="${pkgs.bash}/bin/bash"
    export EDITOR="${self.packages.${system}.helix}/bin/hx"
    export PATH="${pkgs.lib.makeBinPath (tools ++ wrapped)}:$PATH"
    exec ${pkgs.bash}/bin/bash --rcfile ${envrc} "$@"
  '';
in
pkgs.symlinkJoin {
  name = "env";
  paths = tools ++ wrapped ++ [ env ];
}