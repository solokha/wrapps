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
      // Закрытие окна / выход из сессии
      Mod+W { close-window; }
      Mod+Q { close-window; }
      Mod+Shift+E { quit; }

      // Фокус: колонки и окна
      Mod+Left  { focus-column-left; }
      Mod+Right { focus-column-right; }
      Mod+Up    { focus-window-up; }
      Mod+Down  { focus-window-down; }
      Mod+H     { focus-column-left; }
      Mod+L     { focus-column-right; }
      Mod+K     { focus-window-up; }
      Mod+J     { focus-window-down; }

      // Перемещение колонок/окон
      Mod+Ctrl+Left  { move-column-left; }
      Mod+Ctrl+Right { move-column-right; }
      Mod+Ctrl+Up    { move-window-up; }
      Mod+Ctrl+Down  { move-window-down; }
      Mod+Home       { focus-column-first; }
      Mod+End        { focus-column-last; }
      Mod+Ctrl+Home  { move-column-to-first; }
      Mod+Ctrl+End   { move-column-to-last; }

      // Воркспейсы
      Mod+Page_Up          { focus-workspace-up; }
      Mod+Page_Down        { focus-workspace-down; }
      Mod+U                { focus-workspace-up; }
      Mod+I                { focus-workspace-down; }
      Mod+Shift+Page_Up    { move-workspace-up; }
      Mod+Shift+Page_Down  { move-workspace-down; }

      Mod+1 { focus-workspace "w0"; }
      Mod+2 { focus-workspace "w1"; }
      Mod+3 { focus-workspace "w2"; }
      Mod+4 { focus-workspace "w3"; }
      Mod+5 { focus-workspace "w4"; }

      Mod+Shift+1 { move-column-to-workspace "w0"; }
      Mod+Shift+2 { move-column-to-workspace "w1"; }
      Mod+Shift+3 { move-column-to-workspace "w2"; }

      // Колесо
      Mod+WheelScrollUp          { focus-workspace-up; }
      Mod+WheelScrollDown        { focus-workspace-down; }
      Mod+Ctrl+WheelScrollUp     { move-column-to-workspace-up; }
      Mod+Ctrl+WheelScrollDown   { move-column-to-workspace-down; }
      Mod+WheelScrollLeft        { focus-column-left; }
      Mod+WheelScrollRight       { focus-column-right; }

      // Окно и раскладка
      Mod+F { maximize-column; }
      Mod+G { fullscreen-window; }
      Mod+M { maximize-window-to-edges; }
      Mod+C { center-column; }
      Mod+R { switch-preset-column-width; }
      Mod+T { toggle-column-tabbed-display; }
      Mod+V { toggle-window-floating; }
      Mod+Shift+V { switch-focus-between-floating-and-tiling; }

      // Точная настройка размера
      Mod+Ctrl+H { set-column-width "-5%"; }
      Mod+Ctrl+L { set-column-width "+5%"; }
      Mod+Ctrl+J { set-window-height "-5%"; }
      Mod+Ctrl+K { set-window-height "+5%"; }

      // Композитор
      Mod+O { toggle-overview; }
      Mod+Shift+Slash { show-hotkey-overlay; }
      Mod+Shift+P { power-off-monitors; }
      Print { screenshot; }

      // Приложения
      Mod+Return { spawn "${terminal}"; }
      Mod+D { spawn "${launcher}"; }

      // Аудио
      XF86AudioRaiseVolume { spawn-sh "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%+"; }
      XF86AudioLowerVolume { spawn-sh "wpctl set-volume -l 1.4 @DEFAULT_AUDIO_SINK@ 5%-"; }
    }

    layout {
      gaps 5
      focus-ring {
        width 2
        active-color "#fe8019"
      }
    }

    // Тема из noctalia (26.04 умеет ~ и optional=true).
    // Когда noctalia применяет тему — цвета здесь перекрывают fallback ниже.
    include optional=true "~/.config/niri/noctalia.kdl"

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