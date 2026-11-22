{
  pkgs,
  inputs,
  ...
}:
# Настройки Noctalia как атрибуты: wrapper-модуль сам генерирует
# settings.toml в store и выставляет NOCTALIA_CONFIG_HOME. Отдельный
# config.toml не нужен — источник правды здесь.
inputs.nix-wrapper-modules.wrappers.noctalia.wrap {
  inherit pkgs;

  settings = {
    theme = {
      # Палитра community, а не builtin. Пока нет location — тёмная тема;
      # координаты из sops появятся, когда infra научится собирать конфиг
      # во время запуска, тогда mode станет auto.
      mode = "dark";
      source = "community";
      community_palette = "Everforest Alt";
      shell_mode = "follow";

      templates = {
        enable_builtin_templates = true;
        builtin_ids = ["btop" "foot" "gtk3" "gtk4" "niri" "qt" "starship"];

        # Community-шаблоны Noctalia обновляет при старте и кэширует в
        # ~/.local/state/noctalia, каталог вынесен в cache-контракт infra.
        # Шаблон может не отработать, если клиента нет в системе или шаблон
        # ещё не выкачан; это видно в журнале, и такие id убирать не нужно.
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

    # Бар — именованная подтаблица: `[bar]` с полями не читается.
    # position: top | bottom | left | right; right = вертикальный справа.
    bar.default = {
      position = "right";

      # Ширина вертикального бара. 42 px — между дефолтными 34 и 48.
      thickness = 42;

      # Крупнее иконки и текст; 1.1 — чуть больше дефолта без перебора.
      scale = 1.1;

      # Отступы как у окон (niri gaps 6): бар не липнет к кромке экрана.
      margin_ends = 6;
      margin_edge = 6;

      # concave_edge_corners по умолчанию вырезает углы в обратную сторону,
      # поэтому выключен.
      concave_edge_corners = false;
      radius_top_left = 6;
      radius_bottom_left = 6;
      radius_top_right = 6;
      radius_bottom_right = 6;

      # Дефолт 6 — иконки слипаются; при толщине 42 держим пропорцию ~15.
      widget_spacing = 15;

      # Состав под вертикальный бар. Из дефолта не вошли: launcher,
      # wallpaper, media, clipboard, brightness.
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
      # Раскладка прижата к системным значкам, до кнопки питания — зазор.
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
      # Стабильный путь в HOME: desktop кладёт файл туда при старте,
      # store-путь исчез бы при сборке мусора.
      enabled = true;
      fill_mode = "crop";
      directory = "~/.local/share/wallpapers";

      default.path = "~/.local/share/wallpapers/ef_the_cat_returns.jpg";
    };

    lockscreen_widgets.enabled = false;

    # Панели открываются у места клика, а не центрируются вдоль бара.
    shell.panel = {
      open_near_click_control_center = true;
      open_near_click_session = true;
    };
  };
}
