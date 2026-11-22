{
  pkgs,
  inputs,
  ...
}:
inputs.nix-wrapper-modules.wrappers.eza.wrap {
  inherit pkgs;
}
