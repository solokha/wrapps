{
  description = "Portable desktop environment and wrapped packages";

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-master, nix-wrapper-modules, noctalia, ... } @ inputs:
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
          };
        in
        {
          zellij = callModule "zellij";
          helix  = callModule "helix";
          nh     = callModule "nh";
          # foot      = callModule "foot";
          # fuzzel    = callModule "fuzzel";
          # zed       = callModule "zed";
          # niri      = callModule "niri";
          # kitty     = callModule "kitty";
          # which-key = callModule "which-key";
          # firefox   = callModule "firefox";
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
            zellij = self.packages.${system}.zellij;
            helix  = self.packages.${system}.helix;
            nh     = self.packages.${system}.nh;
            # foot      = self.packages.${system}.foot;
            # fuzzel    = self.packages.${system}.fuzzel;
            # zed       = self.packages.${system}.zed;
            # niri      = self.packages.${system}.niri;
            # kitty     = self.packages.${system}.kitty;
            # which-key = self.packages.${system}.which-key;
            # firefox   = self.packages.${system}.firefox;
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
    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };
  };
}
