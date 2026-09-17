{ pkgs, lib, self, ... }:
let
  terminal = "${self.packages.${pkgs.stdenv.hostPlatform.system}.foot}/bin/foot";
  launcher = "${self.packages.${pkgs.stdenv.hostPlatform.system}.fuzzel}/bin/fuzzel";

  cfg = pkgs.writeText "niri-config.kdl" ''
    prefer-no-csd

    input {
      keyboard {
        xkb {
          layout "us,ru"
          options "grp:win_space_toggle,caps:escape"
        }
        repeat-rate 30
        repeat-delay 300
      }
      touchpad {
        natural-scroll
        tap
      }
      mouse {
        accel-profile "flat"
      }
    }

    binds {
      Mod+Return { spawn "${terminal}"; }
      Mod+Q { close-window; }
      Mod+F { maximize-column; }
      Mod+G { fullscreen-window; }
      Mod+Shift+F { toggle-window-floating; }
      Mod+C { center-column; }

      Mod+H { focus-column-left; }
      Mod+L { focus-column-right; }
      Mod+K { focus-window-up; }
      Mod+J { focus-window-down; }

      Mod+1 { focus-workspace "w0"; }
      Mod+2 { focus-workspace "w1"; }
      Mod+3 { focus-workspace "w2"; }
      Mod+4 { focus-workspace "w3"; }
      Mod+5 { focus-workspace "w4"; }

      Mod+Shift+1 { move-column-to-workspace "w0"; }
      Mod+Shift+2 { move-column-to-workspace "w1"; }
      Mod+Shift+3 { move-column-to-workspace "w2"; }

      Mod+D { spawn "${launcher}"; }

      XF86AudioRaiseVolume { spawn-sh "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+"; }
      XF86AudioLowerVolume { spawn-sh "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-"; }

      Mod+Ctrl+H { set-column-width "-5%"; }
      Mod+Ctrl+L { set-column-width "+5%"; }
      Mod+Ctrl+J { set-window-height "-5%"; }
      Mod+Ctrl+K { set-window-height "+5%"; }

      Mod+WheelScrollDown { focus-column-left; }
      Mod+WheelScrollUp { focus-column-right; }
      Mod+Ctrl+WheelScrollDown { focus-workspace-down; }
      Mod+Ctrl+WheelScrollUp { focus-workspace-up; }
    }

    layout {
      gaps 5
      focus-ring {
        width 2
        active-color "#fe8019"
      }
    }

    xwayland-satellite {
      path "${lib.getExe pkgs.xwayland-satellite}"
    }
  '';
in
pkgs.symlinkJoin {
  name = "niri-wrapped";
  paths = [ pkgs.niri ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  meta.mainProgram = "niri";
  postBuild = ''
    wrapProgram $out/bin/niri --add-flags "--config ${cfg}"
  '';
}
