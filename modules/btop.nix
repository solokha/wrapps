{
  pkgs,
  inputs,
  ...
}:
inputs.nix-wrapper-modules.wrappers.btop.wrap {
  inherit pkgs;

  settings.color_theme = "noctalia";
}
