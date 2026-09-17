{ pkgs, ... }:
let
  settings = pkgs.writeText "settings.json" ''
    {
      "theme": {
        "mode": "system",
        "light": "Gruvbox Light",
        "dark": "Gruvbox Dark"
      },
      "ui_font_size": 18,
      "buffer_font_size": 18,
      "buffer_font_family": "JetBrainsMono Nerd Font",
      "terminal": {
        "font_size": 18,
        "font_family": "JetBrainsMono Nerd Font",
        "line_height": {
          "custom": 1.2
        }
      },
      "relative_line_numbers": "enabled",
      "show_breadcrumbs": true,
      "tab_bar": {
        "show": true
      },
      "tabs": {
        "git_status": true
      },
      "scrollbar": {
        "git_status": true
      }
    }
  '';

  keymap = pkgs.writeText "keymap.json" ''
    [
      {
        "context": "Workspace",
        "bindings": {
          "shift shift": "file_finder::Toggle"
        }
      }
    ]
  '';
in
pkgs.symlinkJoin {
  name = "zed-wrapped";
  paths = [ pkgs.zed-editor ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  meta.mainProgram = "zeditor";
  postBuild = ''
    cat > $out/bin/zed-launch << 'EOF'
#!/bin/sh
set -e

ZED_CONFIG_DIR="$HOME/.config/zed"

if [ ! -f "$ZED_CONFIG_DIR/settings.json" ]; then
  mkdir -p "$ZED_CONFIG_DIR"
  cp ${settings} "$ZED_CONFIG_DIR/settings.json"
fi

if [ ! -f "$ZED_CONFIG_DIR/keymap.json" ]; then
  mkdir -p "$ZED_CONFIG_DIR"
  cp ${keymap} "$ZED_CONFIG_DIR/keymap.json"
fi

exec ${pkgs.zed-editor}/bin/zeditor "$@"
EOF
    chmod +x $out/bin/zed-launch
    ln -sf zed-launch $out/bin/zeditor
  '';
}
