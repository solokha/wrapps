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
          desktop  = import ./desktop { inherit pkgs inputs self; };
          env      = import ./env { inherit pkgs pkgs-unstable pkgs-master inputs self; };
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
          inherit (self.packages.${system}) env desktop;
          inherit pkgs-unstable pkgs-master;
        };

      nixosModules = {
        # Базовые пакеты: env, desktop и все wrapps
        default = { config, lib, pkgs, ... }: {
          environment.systemPackages = [
            self.packages.${pkgs.stdenv.hostPlatform.system}.env
            self.packages.${pkgs.stdenv.hostPlatform.system}.desktop
          ];
        };

        # Полная desktop-интеграция: greetd + niri + noctalia
        desktop = { config, lib, pkgs, ... }: {
          imports = [ self.nixosModules.default ];

          services.greetd = {
            enable = true;
            settings.default_session = {
              user = "greeter";
              command = "${pkgs.tuigreet}/bin/tuigreet --time --asterisks --remember --cmd 'dbus-run-session ${self.packages.${pkgs.stdenv.hostPlatform.system}.desktop}/bin/desktop'";
            };
          };
        };
      };
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
