{
  description = "Portable desktop environment and wrapped packages";

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-master, nix-wrapper-modules, ... } @ inputs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        inherit system;
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
        pkgs-unstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };
        pkgs-master = import nixpkgs-master { inherit system; config.allowUnfree = true; };
      });
    in
    {
      packages = forAllSystems ({ system, pkgs, pkgs-unstable, pkgs-master }:
        let
          callModule = name: import (./modules + "/${name}.nix") {
            inherit pkgs pkgs-unstable pkgs-master inputs self;
            lib = nixpkgs.lib;
          };
        in
        {
          zellij   = callModule "zellij";
          helix    = callModule "helix";
          nh       = callModule "nh";
          foot     = callModule "foot";
          fuzzel   = callModule "fuzzel";
          kitty    = callModule "kitty";
          zed      = callModule "zed";
          niri     = callModule "niri";
          firefox  = callModule "firefox";
          noctalia = import ./noctalia { inherit pkgs pkgs-unstable; };
          # which-key = callModule "which-key";
          desktop   = import ./desktop { inherit pkgs inputs self; };
          env       = import ./env { inherit pkgs pkgs-unstable pkgs-master inputs self; };
        }
      );

      overlays.default = final: prev:
        let
          system = final.stdenv.hostPlatform.system;
          pkgs-unstable = import nixpkgs-unstable { inherit system; config.allowUnfree = true; };
          pkgs-master = import nixpkgs-master { inherit system; config.allowUnfree = true; };
        in
        {
          wrapps = {
            zellij   = self.packages.${system}.zellij;
            helix    = self.packages.${system}.helix;
            nh       = self.packages.${system}.nh;
            foot     = self.packages.${system}.foot;
            fuzzel   = self.packages.${system}.fuzzel;
            kitty    = self.packages.${system}.kitty;
            zed      = self.packages.${system}.zed;
            niri     = self.packages.${system}.niri;
            firefox  = self.packages.${system}.firefox;
            noctalia = self.packages.${system}.noctalia;
          };
          inherit pkgs-unstable pkgs-master;
        };

      nixosModules = { };
    };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nix-wrapper-modules = {
      url = "github:nix-community/nix-wrapper-modules";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
