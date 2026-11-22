{
  pkgs,
  inputs,
  ...
}:
inputs.nix-wrapper-modules.wrappers.bat.wrap {
  inherit pkgs;

  preBakeCache = false;

  settings = {
    style = "auto";
    italic-text = "always";
  };

  runShell = [
    ''
      cfg_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/bat"
      if [ ! -f "$cfg_dir/config" ]; then
        mkdir -p "$cfg_dir"
        install -m 644 ${builtins.placeholder "out"}/bat-config/config "$cfg_dir/config"
      fi
      export BAT_CONFIG_DIR="$cfg_dir"
      unset BAT_CACHE_PATH
    ''
  ];
}
