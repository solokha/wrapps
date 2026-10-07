{inputs}: final: prev: let
  system = final.stdenv.hostPlatform.system;
in {
  unstable = import inputs.nixpkgs-unstable {
    inherit system;
    config.allowUnfree = true;
  };
  master = import inputs.nixpkgs-master {
    inherit system;
    config.allowUnfree = true;
  };
  # far2l — порт FAR Manager. Переопределяем, потому что nixpkfs по умолчанию
  # собирает его с GUI-бэкендом на wxWidgets: это 1.1 GiB и GTK в дереве.
  #
  # withGUI=false — TUI, и тогда вопрос оформления не возникает: палитра
  # noctalia до far2l не доходит (GTK3/GTK4), да и не должна.
  # withNetRocks=false — своя сеть с samba, openssl, libssh, libnfs и neon
  # стоит 340 MiB. smb:// и носители берутся через gvfs, смонтированные в
  # /run/user/1000/gvfs, оттуда far2l их видит.
  # withMultiArc остаётся включённым: libarchive даёт просмотр архива изнутри.
  # Итог — 253.8 MiB и 102 пакета против 337 MiB у thunar, без GTK.
  far2l = prev.far2l.override {
    withGUI = false;
    withNetRocks = false;
  };
  wrapps = {
    zellij = inputs.self.packages.${system}.zellij;
    helix = inputs.self.packages.${system}.helix;
    nh = inputs.self.packages.${system}.nh;
    foot = inputs.self.packages.${system}.foot;
    fuzzel = inputs.self.packages.${system}.fuzzel;
    zed = inputs.self.packages.${system}.zed;
    niri = inputs.self.packages.${system}.niri;
    firefox = inputs.self.packages.${system}.firefox;
    noctalia = inputs.self.packages.${system}.noctalia;
    nixos-anywhere = inputs.self.packages.${system}.nixos-anywhere;
  };
  inherit (inputs.self.packages.${system}) env desktop;
}
