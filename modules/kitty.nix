{ pkgs, ... }:
let
  cfg = pkgs.writeText "kitty.conf" ''
    enable_audio_bell no
    font_size 15
    font_family JetBrainsMono Nerd Font
    cursor_text_color background
    allow_remote_control yes
    shell_integration enabled
    cursor_trail 3

    map alt+1 goto_tab 1
    map alt+2 goto_tab 2
    map alt+3 goto_tab 3
    map alt+4 goto_tab 4
    map alt+5 goto_tab 5
    map alt+6 goto_tab 6
    map alt+7 goto_tab 7
    map alt+8 goto_tab 8
    map alt+9 goto_tab 9
    map ctrl+shift+w close_tab
    map ctrl+t new_tab_with_cwd
    map ctrl+shift+t new_tab
  '';
in
pkgs.symlinkJoin {
  name = "kitty-wrapped";
  paths = [ pkgs.kitty ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  meta.mainProgram = "kitty";
  postBuild = ''
    wrapProgram $out/bin/kitty --add-flags "--config ${cfg}"
  '';
}
