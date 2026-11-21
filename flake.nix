{
  description = "Portable desktop environment and wrapped packages";

  outputs = {
    self,
    nixpkgs,
    nixpkgs-unstable,
    nixpkgs-master,
    nix-wrapper-modules,
    ...
  } @ inputs: let
    systems = ["x86_64-linux" "aarch64-linux"];
    overlay = import ./overlay.nix {inherit inputs;};
    mkFirefox = {
      pkgs,
      sitePolicies ? [],
      themeSync ? null,
    }:
      import ./modules/firefox.nix {inherit pkgs sitePolicies themeSync;};
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
        themeSync = import ./modules/firefox-theme-sync.nix {inherit pkgs;};
        gtkThemeSync = pkgs.writeShellScriptBin "noctalia-gtk-sync" ''
          set -eu
          mode="''${1:-dark}"
          case "$mode" in
            light) theme=adw-gtk3; prefer=0; scheme=prefer-light ;;
            *)     theme=adw-gtk3-dark; prefer=1; scheme=prefer-dark ;;
          esac

          for d in gtk-3.0 gtk-4.0; do
            dir="''${XDG_CONFIG_HOME:-$HOME/.config}/$d"
            f="$dir/settings.ini"
            mkdir -p "$dir"
            touch "$f"
            grep -q '^\[Settings\]' "$f" || printf '[Settings]\n' >> "$f"
            sed -i '/^gtk-theme-name=/d; /^gtk-application-prefer-dark-theme=/d' "$f"
            printf 'gtk-theme-name=%s\ngtk-application-prefer-dark-theme=%s\n' "$theme" "$prefer" >> "$f"
          done

          if command -v gsettings >/dev/null 2>&1; then
            gsettings set org.gnome.desktop.interface gtk-theme "$theme" 2>/dev/null || true
            gsettings set org.gnome.desktop.interface color-scheme "$scheme" 2>/dev/null || true
          fi
        '';
      in {
        nh = callModule "nh";
        opencode = callModule "opencode";
        opencode2-desktop = callModule "opencode2-desktop";
        foot = callModule "foot";
        fuzzel = callModule "fuzzel";
        zed = callModule "zed";
        niri = callModule "niri";
        firefox = mkFirefox {inherit pkgs; themeSync = themeSync.xpi;};
        firefox-theme-sync = themeSync.xpi;
        firefox-theme-sync-host = themeSync.host;
        noctalia-gtk-sync = gtkThemeSync;
        tg-web = callModule "tg-web";
        noctalia = import ./noctalia {inherit pkgs;};
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
              self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia
              self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia-gtk-sync
              (import ./modules/firefox.nix {
                inherit pkgs;
                inherit (config.wrapps.firefox) sitePolicies;
                themeSync = self.packages.${pkgs.stdenv.hostPlatform.system}.firefox-theme-sync;
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
        ];
        xdg.mime.defaultApplications."x-scheme-handler/tg" = "tg-web.desktop";

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
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
}
