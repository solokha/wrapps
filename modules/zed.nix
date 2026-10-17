{pkgs, ...}: let
  # Единый дефолт для всех хостов. Секретов здесь нет и быть не может — только
  # несекретные предпочтения (агент, модели, тема, шрифты). Учётные данные
  # (API-ключи, токены) живут вне wrapps: их держат сами приложения в
  # персистентном HOME, а per-host значения приходят из окружения. Подробности —
  # README.md, раздел про секреты.
  prefs = {
    favorite_config_option_values = {
      model = ["opencode/deepseek-v4.1-flash-free"];
      mode = ["plan"];
    };
    default_config_options = {
      effort = "high";
      mode = "plan";
      model = "opencode/deepseek-v4.1-flash-free";
    };
  };

  mkSettings = opencode:
    pkgs.writeText "settings.json" (builtins.toJSON {
      cli_default_open_behavior = "existing_window";
      agent = {
        thinking_display = "always_collapsed";
        favorite_models = [];
        model_parameters = [];
        enable_feedback = false;
      };
      agent_servers = {inherit opencode;};
      theme = {
        mode = "dark";
        light = "Noctalia Light";
        dark = "Noctalia Dark";
      };
      ui_font_size = 18;
      buffer_font_size = 18;
      buffer_font_family = "FiraCode Nerd Font";
      terminal = {
        font_size = 18;
        font_family = "FiraCode Nerd Font";
        line_height = {custom = 1.2;};
      };
      relative_line_numbers = "enabled";
      show_breadcrumbs = true;
      tab_bar = {show = true;};
      tabs = {git_status = true;};
      scrollbar = {git_status = true;};
    });

  # Файл настроек пишется только когда его ещё нет, поэтому выбор делается один
  # раз при первом запуске: есть opencode в PATH — ACP ведём прямо на него
  # (stdio), нет (живой образ, `nix run .#env` без пакета) — остаётся реестровый.
  settingsHost = mkSettings ({
      type = "custom";
      command = "opencode";
      args = ["acp"];
      env = {};
    }
    // prefs);
  settingsRegistry = mkSettings ({type = "registry";} // prefs);

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
    paths = [pkgs.zed-editor];
    nativeBuildInputs = [pkgs.makeWrapper];
    meta.mainProgram = "zeditor";
    postBuild = ''
          cat > $out/bin/zed-launch << 'EOF'
      #!/bin/sh
      set -e

      ZED_CONFIG_DIR="$HOME/.config/zed"

      if [ ! -f "$ZED_CONFIG_DIR/settings.json" ]; then
        mkdir -p "$ZED_CONFIG_DIR"
        if command -v opencode >/dev/null 2>&1; then
          cp ${settingsHost} "$ZED_CONFIG_DIR/settings.json"
        else
          cp ${settingsRegistry} "$ZED_CONFIG_DIR/settings.json"
        fi
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
