{ pkgs, inputs, ... }:
inputs.nix-wrapper-modules.lib.wrapPackage {
  inherit pkgs;
  package = pkgs.zellij;
  flags."--config" = pkgs.writeText "zellij-config.kdl" ''
    default_shell "bash"
    pane_frames false
    theme "gruvbox-dark"
    default_layout "compact"
  '';
}
