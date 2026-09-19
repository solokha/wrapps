{ pkgs, ... }:
let
  cfg = pkgs.writeText "foot.ini" ''
    [main]
    term=xterm-256color
    font=JetBrainsMono Nerd Font:size=15
    pad=8x8 center
    include=~/.config/foot/themes/noctalia

    [scrollback]
    lines=50000

    [mouse]
    hide-when-typing=yes

    [url]
    launch=xdg-open ''${url}
    osc8-underline=url-mode
    label-letters=sadfjklewcmpgh
  '';

  # Палитра активной темы noctalia (builtin Kanagawa) — тот же контент, что
  # noctalia пишет сама в $XDG_CONFIG_HOME/foot/themes/noctalia, поэтому
  # pre-warm до первого применения темы даёт тот же вид.
  fallbackTheme = pkgs.writeText "foot-noctalia.fallback" ''
    [colors-dark]
    foreground=545464
    background=f2ecbc

    regular0=1f1f28
    regular1=c84053
    regular2=6f894e
    regular3=77713f
    regular4=4d699b
    regular5=b35b79
    regular6=597b75
    regular7=545464

    bright0=8a8980
    bright1=d7474b
    bright2=6e915f
    bright3=836f4a
    bright4=6693bf
    bright5=624c83
    bright6=5e857a
    bright7=43436c

    selection-foreground=f2ecbc
    selection-background=c9cbd1
    cursor=f2ecbc 43436c
  '';
in
pkgs.writeShellScriptBin "foot" ''
  theme_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/foot/themes"
  theme="$theme_dir/noctalia"

  # Пока noctalia не применила тему — кладём фолбэк, чтобы foot стартовал даже
  # в standalone (missing include у foot — фатальная ошибка).
  if [ ! -f "$theme" ]; then
    mkdir -p "$theme_dir"
    cat ${fallbackTheme} >"$theme"
  fi

  exec ${pkgs.foot}/bin/foot --config ${cfg} "$@"
''