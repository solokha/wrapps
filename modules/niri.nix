{
  pkgs,
  lib,
  self,
  inputs,
  ...
}: let
  terminal = "${self.packages.${pkgs.stdenv.hostPlatform.system}.foot}/bin/foot";
  launcher = "${self.packages.${pkgs.stdenv.hostPlatform.system}.fuzzel}/bin/fuzzel";
  noctalia = "${self.packages.${pkgs.stdenv.hostPlatform.system}.noctalia}/bin/noctalia";
  niri = "${pkgs.niri}/bin/niri";

  quake = pkgs.writeShellScriptBin "quake" ''
    set -eu
    win="$(${niri} msg --json windows | ${pkgs.jq}/bin/jq -r '[.[] | select(.app_id == "dropdown")][0].id // empty')"
    if [ -n "$win" ]; then
      exec ${niri} msg action close-window --id "$win"
    fi
    exec ${terminal} --app-id=dropdown ${self.packages.${pkgs.stdenv.hostPlatform.system}.tmux}/bin/tmux new-session -A -s quake
  '';
in
  inputs.nix-wrapper-modules.wrappers.niri.wrap {
    inherit pkgs;

    settings = {
      prefer-no-csd = _: {};

      spawn-at-startup = [
        noctalia
        (lib.getExe' pkgs.bluez "mpris-proxy")
      ];

      input = {
        keyboard = {
          xkb = {
            layout = "us,ru";
            options = "grp:win_space_toggle,caps:escape";
          };
          repeat-rate = 30;
          repeat-delay = 300;
        };

        touchpad = {
          natural-scroll = _: {};
          tap = _: {};
        };

        mouse.accel-profile = "flat";
      };

      binds = {
        "Mod+W".close-window = _: {};
        "Mod+Q".close-window = _: {};
        "Mod+Shift+E".quit = _: {};

        "Mod+Left".focus-column-left = _: {};
        "Mod+Right".focus-column-right = _: {};
        "Mod+Up".focus-window-up = _: {};
        "Mod+Down".focus-window-down = _: {};
        "Mod+H".focus-column-left = _: {};
        "Mod+L".focus-column-right = _: {};
        "Mod+K".focus-window-up = _: {};
        "Mod+J".focus-window-down = _: {};

        "Mod+Ctrl+Left".move-column-left = _: {};
        "Mod+Ctrl+Right".move-column-right = _: {};
        "Mod+Ctrl+Up".move-window-up = _: {};
        "Mod+Ctrl+Down".move-window-down = _: {};
        "Mod+Comma".focus-column-first = _: {};
        "Mod+Period".focus-column-last = _: {};
        "Mod+Ctrl+Comma".move-column-to-first = _: {};
        "Mod+Ctrl+Period".move-column-to-last = _: {};

        "Mod+U".focus-workspace-up = _: {};
        "Mod+I".focus-workspace-down = _: {};
        "Mod+Shift+U".move-workspace-up = _: {};
        "Mod+Shift+I".move-workspace-down = _: {};

        "Mod+1".focus-workspace = "w0";
        "Mod+2".focus-workspace = "w1";
        "Mod+3".focus-workspace = "w2";
        "Mod+4".focus-workspace = "w3";
        "Mod+5".focus-workspace = "w4";

        "Mod+Shift+1".move-column-to-workspace = "w0";
        "Mod+Shift+2".move-column-to-workspace = "w1";
        "Mod+Shift+3".move-column-to-workspace = "w2";
        "Mod+Shift+4".move-column-to-workspace = "w3";
        "Mod+Shift+5".move-column-to-workspace = "w4";

        "Mod+WheelScrollUp".focus-workspace-up = _: {};
        "Mod+WheelScrollDown".focus-workspace-down = _: {};
        "Mod+Ctrl+WheelScrollUp".move-column-to-workspace-up = _: {};
        "Mod+Ctrl+WheelScrollDown".move-column-to-workspace-down = _: {};
        "Mod+WheelScrollLeft".focus-column-left = _: {};
        "Mod+WheelScrollRight".focus-column-right = _: {};

        "Mod+F".maximize-column = _: {};
        "Mod+G".fullscreen-window = _: {};
        "Mod+M".maximize-window-to-edges = _: {};
        "Mod+C".center-column = _: {};
        "Mod+R".switch-preset-column-width = _: {};
        "Mod+T".toggle-column-tabbed-display = _: {};
        "Mod+V".toggle-window-floating = _: {};
        "Mod+Shift+V".switch-focus-between-floating-and-tiling = _: {};

        "Mod+Ctrl+H".set-column-width = "-5%";
        "Mod+Ctrl+L".set-column-width = "+5%";
        "Mod+Ctrl+J".set-window-height = "-5%";
        "Mod+Ctrl+K".set-window-height = "+5%";

        "Mod+O".toggle-overview = _: {};
        "Mod+Shift+Slash".show-hotkey-overlay = _: {};
        "Mod+Shift+P".power-off-monitors = _: {};
        "Mod+Shift+S".screenshot = _: {};

        "Mod+Return".spawn = [terminal];
        "Mod+D".spawn = [launcher];
        "Mod+grave".spawn-sh = "${quake}/bin/quake";

        "XF86AudioRaiseVolume".spawn-sh = "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+";
        "XF86AudioLowerVolume".spawn-sh = "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-";
        "XF86AudioMute".spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        "XF86AudioMicMute".spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
        "XF86AudioPlay".spawn-sh = "${pkgs.playerctl}/bin/playerctl play-pause";
        "XF86AudioNext".spawn-sh = "${pkgs.playerctl}/bin/playerctl next";
        "XF86AudioPrev".spawn-sh = "${pkgs.playerctl}/bin/playerctl previous";
        "XF86MonBrightnessUp".spawn-sh = "${pkgs.brightnessctl}/bin/brightnessctl set 5%+";
        "XF86MonBrightnessDown".spawn-sh = "${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
      };

      layout = {
        gaps = 6;
        focus-ring.width = 3;
      };

      window-rules = [
        {
          geometry-corner-radius = 12;
          clip-to-geometry = true;
        }
        {
          matches = [{app-id = "^dropdown$";}];
          open-floating = true;
          default-floating-position = _: {
            props = {
              x = 0;
              y = 0;
              relative-to = "top";
            };
          };
          default-window-height = {proportion = 0.5;};
          default-column-width = {proportion = 0.8;};
        }
      ];
    };

    extraSettings = [
      {include = [{optional = true;} "/etc/niri/user-dirs.kdl"];}
      {include = [{optional = true;} "/etc/niri/cursor.kdl"];}
      {include = [{optional = true;} "~/.config/niri/noctalia.kdl"];}
    ];
  }
