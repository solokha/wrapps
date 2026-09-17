{ pkgs, ... }:
let
  cfg = pkgs.writeText "fuzzel.ini" ''
    [main]
    font=JetBrainsMono Nerd Font:size=12
    terminal=foot -e
    prompt="> "
    lines=10
    width=48
    horizontal-pad=18
    vertical-pad=14
    inner-pad=10
    icon-theme=Gruvbox-Plus-Dark
    dpi-aware=yes
    show-actions=yes
    layer=overlay

    [colors]
    background=1d2021f2
    text=ebdbb2ff
    prompt=83a598ff
    placeholder=928374ff
    input=fbf1c7ff
    match=fabd2fff
    selection=3c3836ff
    selection-text=fbf1c7ff
    selection-match=fabd2fff
    border=83a598ff
  '';
in
pkgs.symlinkJoin {
  name = "fuzzel-wrapped";
  paths = [ pkgs.fuzzel ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  meta.mainProgram = "fuzzel";
  postBuild = ''
    wrapProgram $out/bin/fuzzel --add-flags "--config=${cfg}"
  '';
}
