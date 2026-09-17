{ pkgs, pkgs-unstable, pkgs-master, inputs, self }:
let
  system = pkgs.stdenv.hostPlatform.system;

  tools = import ./packages.nix { inherit pkgs pkgs-unstable pkgs-master; };

  wrapped = [
    self.packages.${system}.helix
    self.packages.${system}.zellij
    self.packages.${system}.nh
  ];

  env = pkgs.writeShellScriptBin "env" ''
    export SHELL="${pkgs.bash}/bin/bash"
    export EDITOR="${self.packages.${system}.helix}/bin/hx"
    export PATH="${pkgs.lib.makeBinPath (tools ++ wrapped)}:$PATH"
    exec ${pkgs.bash}/bin/bash "$@"
  '';
in
pkgs.symlinkJoin {
  name = "env";
  paths = tools ++ wrapped ++ [ env ];
}
