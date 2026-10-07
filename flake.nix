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
        zellij = callModule "zellij";
        helix = callModule "helix";
        nh = callModule "nh";
        foot = callModule "foot";
        fuzzel = callModule "fuzzel";
        zed = callModule "zed";
        niri = callModule "niri";
        firefox = callModule "firefox";
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
        environment.systemPackages =
          (with pkgs; [
            # Файлового менеджера нет намеренно. thunar (GTK3, 337 MiB) и
            # file-roller (1.2 GiB замыкания, и он тянет за собой целый
            # nautilus) убраны: первый не оформлялся, второй тянул лишнее.
            # Кандидаты на замену — far2l без GUI (254 MiB, встроенные
            # архивы) и vifm (55.5 MiB, только ncurses) — отвергнуты.
            # Файлы и smb:// остаются доступны через консоль и через
            # смонтированное в /run/user/1000/gvfs.
            gvfs
            udisks
            xdg-desktop-portal-gtk
          ])
          ++ [
            self.packages.${pkgs.stdenv.hostPlatform.system}.env
            self.packages.${pkgs.stdenv.hostPlatform.system}.desktop
            self.packages.${pkgs.stdenv.hostPlatform.system}.firefox
            self.packages.${pkgs.stdenv.hostPlatform.system}.foot
          ];

        # GIO ищет свои модули в двух местах: в каталоге, скомпилированном в
        # glib (у нас он пуст), и в $XDG_DATA_DIRS/gio/modules (на машине его
        # нет). gvfs же кладёт их в $out/lib/gio/modules — мимо обоих. Без
        # этой переменной не грузится весь gvfs, а не только сеть: в файловом
        # менеджере нет ни smb://, ни Корзины, ни автоподключения носителей
        # (проверено: gio info trash:/// → «Operation not supported»).
        environment.sessionVariables.GIO_EXTRA_MODULES = "${pkgs.gvfs}/lib/gio/modules";
      };

      desktop = {
        config,
        lib,
        pkgs,
        ...
      }: {
        imports = [self.nixosModules.default];

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
