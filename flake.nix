{
  description = "Portable desktop environment and wrapped packages";

  outputs = { self, nixpkgs, nixpkgs-unstable, nixpkgs-master, nix-wrapper-modules, ... } @ inputs:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      overlay = import ./overlay.nix { inherit inputs; };
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f {
        inherit system;
        pkgs = (import nixpkgs { inherit system; config.allowUnfree = true; }).extend overlay;
      });
    in
    {
      packages = forAllSystems ({ system, pkgs }:
        let
          callModule = name: import (./modules + "/${name}.nix") {
            inherit pkgs inputs self;
            lib = nixpkgs.lib;
          };
          env    = import ./env { inherit pkgs inputs self; };
          # Алиасы на тот же пакет: .#env / .#denv / .#shell ведут в один shell.
          # Вынесены в let, чтобы не было eager-самоссылок внутри packages.
          shell  = import ./env { inherit pkgs inputs self; };
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
          noctalia = import ./noctalia { inherit pkgs; };
          desktop  = import ./desktop { inherit pkgs inputs self; };
          # Переустановка хоста: НЕ часть env, вызывается точечно при
          # развёртывании. См. infra/docs/deploy.md.
          nixos-anywhere = pkgs.callPackage ./modules/nixos-anywhere.nix {
            wrapps.nixosAnywhere.enable = true;
            wrapps.nixosAnywhere.extraPackages = with pkgs; [
              disko
              env
            ];
          };
          env      = env;
          shell    = shell;
          denv     = env;
        }
      );

      overlays.default = overlay;

      nixosModules = {
        # Базовые пакеты: env, desktop и все wrapps
        default = { config, lib, pkgs, ... }: {
          environment.systemPackages = [
            self.packages.${pkgs.stdenv.hostPlatform.system}.env
            self.packages.${pkgs.stdenv.hostPlatform.system}.desktop
            self.packages.${pkgs.stdenv.hostPlatform.system}.firefox
            self.packages.${pkgs.stdenv.hostPlatform.system}.foot
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
