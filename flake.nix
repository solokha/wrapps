{
  description = "Portable desktop environment and wrapped packages";

  outputs = {
    self,
    nixpkgs,
    nixpkgs-master,
    nix-wrapper-modules,
    ...
  } @ inputs: let
    systems = ["x86_64-linux" "aarch64-linux"];
    overlay = import ./overlay.nix {inherit inputs;};
    mkFirefox = {
      pkgs,
      sitePolicies ? [],
    }:
      import ./modules/firefox.nix {inherit pkgs sitePolicies;};
    forAllSystems = f:
      nixpkgs.lib.genAttrs systems (system:
        f {
          inherit system;
          pkgs =
            (import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            }).extend
            overlay;
        });
  in {
    packages = forAllSystems (
      {
        system,
        pkgs,
      }: let
        callModule = name:
          import (./modules + "/${name}.nix") {
            inherit pkgs inputs self;
            lib = nixpkgs.lib;
          };
        env = import ./env {inherit pkgs inputs self;};
        shell = import ./env {inherit pkgs inputs self;};
      in {
        opencode = callModule "opencode";
        foot = callModule "foot";
        fuzzel = callModule "fuzzel";
        zed = callModule "zed";
        niri = callModule "niri";
        firefox = mkFirefox {inherit pkgs;};
        tg-web = callModule "tg-web";
        noctalia = import ./noctalia {inherit pkgs inputs;};
        desktop = import ./desktop {inherit pkgs inputs self;};
        nixos-anywhere = callModule "nixos-anywhere";
        env = env;
        shell = shell;
        denv = env;
      }
    );

    checks = forAllSystems ({
      system,
      pkgs,
    }: {
      env = self.packages.${system}.env;
      desktop = self.packages.${system}.desktop;
      opencode = self.packages.${system}.opencode;
      tg-web = self.packages.${system}.tg-web;
    });

    formatter = forAllSystems ({pkgs, ...}: pkgs.alejandra);

    overlays.default = overlay;

    nixosModules = {
      default = {
        config,
        lib,
        pkgs,
        ...
      }: {
        options.wrapps.firefox.sitePolicies = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [];
          description = ''
            Правила Firefox SitePolicies (Policies.Container). Порядок важен:
            первое совпадение выигрывает. В публичном репозитории пусто; хостовые
            домены задаются в infra.
          '';
        };

        config = {
          environment.systemPackages =
            (with pkgs; [
              gvfs
              udisks
              xdg-desktop-portal-gtk
            ])
            ++ [
              self.packages.${pkgs.stdenv.hostPlatform.system}.env
              self.packages.${pkgs.stdenv.hostPlatform.system}.desktop
              (import ./modules/firefox.nix {
                inherit pkgs;
                inherit (config.wrapps.firefox) sitePolicies;
              })
              self.packages.${pkgs.stdenv.hostPlatform.system}.foot
            ];

          environment.sessionVariables.GIO_EXTRA_MODULES = lib.mkDefault "${pkgs.gvfs}/lib/gio/modules";
        };
      };

      desktop = {
        pkgs,
        ...
      }: {
        imports = [self.nixosModules.default];

        # Ссылки tg:// (кнопка «Join Channel» на страницах t.me) отдаются
        # обработчику из этого же репозитория: Firefox схему не умеет, а
        # Telegram Web зарегистрировать её себе не может. Регистрация — та же,
        # что у нативных приложений: .desktop в systemPackages плюс запись в
        # XDG-базе схем (xdg.mime → /etc/xdg/mimeapps.list). Живёт здесь, а не
        # в infra: это десктопная интеграция, и Exec указывает на обёрнутый
        # firefox из wrapps.
        environment.systemPackages = [
          self.packages.${pkgs.stdenv.hostPlatform.system}.tg-web
          pkgs.pcmanfm
          pkgs.engrampa
          pkgs.ungoogled-chromium
        ];
        xdg.mime.defaultApplications."x-scheme-handler/tg" = "tg-web.desktop";
        xdg.mime.defaultApplications."inode/directory" = "pcmanfm.desktop";

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
    # Временно nixos-unstable: нужен oo7 0.7.x и свежие пакеты. При выходе
    # 26.11 меняется только эта строка — остальной флейк не трогаем.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-master.url = "github:NixOS/nixpkgs/master";
    nix-wrapper-modules = {
      url = "github:nix-community/nix-wrapper-modules";
      # Иначе библиотека тянет собственный nixpkgs и второй бинарный кэш.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
