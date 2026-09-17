{ pkgs, ... }:
let
  cfg = pkgs.writeText "foot.ini" ''
    [main]
    term=xterm-256color
    font=JetBrainsMono Nerd Font:size=15
    pad=8x8 center

    [scrollback]
    lines=50000

    [mouse]
    hide-when-typing=yes

    [url]
    launch=xdg-open ''${url}
    osc8-underline=url-mode
    label-letters=sadfjklewcmpgh

    [colors]
    alpha=1.0
    background=242424
    foreground=d5c4a1

    regular0=242424
    regular1=fb4934
    regular2=b8bb26
    regular3=fabd2f
    regular4=7daea3
    regular5=e089a1
    regular6=8ec07c
    regular7=fbf1c7

    bright0=665c54
    bright1=fb4934
    bright2=b8bb26
    bright3=fabd2f
    bright4=7daea3
    bright5=e089a1
    bright6=8ec07c
    bright7=fbf1c7
  '';
in
pkgs.symlinkJoin {
  name = "foot-wrapped";
  paths = [ pkgs.foot ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  meta.mainProgram = "foot";
  postBuild = ''
    wrapProgram $out/bin/foot --add-flags "--config=${cfg}"
  '';
}
