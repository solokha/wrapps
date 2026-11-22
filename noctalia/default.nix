{
  pkgs,
  inputs,
  ...
}:
inputs.nix-wrapper-modules.wrappers.noctalia.wrap {
  inherit pkgs;

  settings = {
    theme = {
      mode = "dark";
      source = "community";
      community_palette = "Everforest Alt";
      shell_mode = "follow";

      templates = {
        enable_builtin_templates = true;
        builtin_ids = ["btop" "foot" "gtk3" "gtk4" "niri" "qt" "starship"];

        community_ids = [
          "opencode"
          "zed"
          "fuzzel"
          "bat"
          "fzf"
          "tmux"
          "micro"
          "ungoogled-chromium"
        ];
      };
    };

    bar.default = {
      position = "right";

      thickness = 42;

      scale = 1.1;

      margin_ends = 6;
      margin_edge = 6;

      concave_edge_corners = false;
      radius_top_left = 6;
      radius_bottom_left = 6;
      radius_top_right = 6;
      radius_bottom_right = 6;

      widget_spacing = 15;

      start = ["control-center" "workspaces"];
      center = ["clock"];
      end = [
        "notifications"
        "power-profile"
        "volume"
        "network"
        "bluetooth"
        "battery"
        "privacy"
        "tray"
        "keyboard_layout"
        "gap"
        "session"
      ];
    };

    widget = {
      gap = {
        type = "spacer";
        length = 24;
      };

      clock = {
        format = "{:%H:%M}";
        vertical_format = "{:%H\n%M}";
      };

      keyboard_layout = {
        show_glyph = true;
        show_label = true;
        display = "short";
      };
    };

    wallpaper = {
      enabled = true;
      fill_mode = "crop";
      directory = "~/.local/share/wallpapers";

      default.path = "~/.local/share/wallpapers/ef_the_cat_returns.jpg";
    };

    lockscreen_widgets.enabled = false;

    shell.panel = {
      open_near_click_control_center = true;
      open_near_click_session = true;
    };
  };
}
