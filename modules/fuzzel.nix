{
  pkgs,
  inputs,
  ...
}:
inputs.nix-wrapper-modules.wrappers.fuzzel.wrap {
  inherit pkgs;
  settings.main = {
    font = "FiraCode Nerd Font:size=14";
    terminal = "foot -e";
    prompt = "> ";
    lines = 10;
    width = 48;
    horizontal-pad = 18;
    vertical-pad = 14;
    inner-pad = 10;
    icon-theme = "Gruvbox-Plus-Dark";
    dpi-aware = "yes";
    show-actions = "yes";
    layer = "overlay";
    include = "~/.config/fuzzel/themes/noctalia";
  };
}
