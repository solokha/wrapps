{
  pkgs,
  inputs,
  self,
}: let
  system = pkgs.stdenv.hostPlatform.system;
  niri = "${self.packages.${system}.niri}/bin/niri";
  noctalia = "${self.packages.${system}.noctalia}/bin/noctalia";
  denv = "${self.packages.${system}.env}/bin/denv";
  shell = "${self.packages.${system}.env}/bin/shell";
in
  pkgs.writeShellScriptBin "desktop" ''
    set -euo pipefail

    log() { printf 'desktop: %s\n' "$*"; }

    wallpaper_dir="''${XDG_DATA_HOME:-$HOME/.local/share}/wallpapers"
    mkdir -p "$wallpaper_dir"
    if ! install -m 644 ${../wallpapers/ef_the_cat_returns.jpg} "$wallpaper_dir/ef_the_cat_returns.jpg"; then
      log "не удалось положить обоину — останется прежняя"
    fi

    starship_config="''${XDG_CONFIG_HOME:-$HOME/.config}/starship.toml"
    if [ ! -f "$starship_config" ]; then
      mkdir -p "$(dirname "$starship_config")"
      if ! install -m 644 ${self.packages.${system}.starship}/starship.toml "$starship_config"; then
        log "не удалось положить конфиг starship — останется дефолтный промпт"
      fi
    fi

    bat_config="''${XDG_CONFIG_HOME:-$HOME/.config}/bat/config"
    if [ ! -f "$bat_config" ]; then
      mkdir -p "$(dirname "$bat_config")"
      if ! install -m 644 ${self.packages.${system}.bat}/bat-config/config "$bat_config"; then
        log "не удалось положить конфиг bat — останутся дефолтные флаги"
      fi
    fi

    chromium_prefs="''${XDG_CONFIG_HOME:-$HOME/.config}/chromium/Default/Preferences"
    if [ ! -f "$chromium_prefs" ]; then
      mkdir -p "$(dirname "$chromium_prefs")"
      if ! printf '%s\n' '{"extensions":{"theme":{"system_theme":1}},"vertical_tabs":{"enabled":true}}' >"$chromium_prefs"; then
        log "не удалось задать стартовые настройки Chromium"
      fi
    fi

    if [ -n "''${WAYLAND_DISPLAY:-}" ] || [ -n "''${DISPLAY:-}" ]; then
      log "запущено внутри ''${WAYLAND_DISPLAY:-$DISPLAY} — desktop требует чистый tty (greetd/логин)"
      exec ${shell} "$@"
    fi

    if command -v gsettings >/dev/null 2>&1; then
      gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3 2>/dev/null || true
      gsettings set org.gnome.desktop.interface icon-theme Gruvbox-Plus-Dark 2>/dev/null || true
      gsettings set org.gnome.desktop.interface color-scheme prefer-dark 2>/dev/null || true
    fi

    rt="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

    ${niri} --session &
    niri_pid=$!

    ok=1
    for _ in $(seq 1 30); do
      sleep 0.5
      if grep -qs " $rt/wayland-" /proc/net/unix; then ok=0; break; fi
      if ! kill -0 "$niri_pid" 2>/dev/null; then break; fi
    done

    if [ "$ok" -ne 0 ]; then
      kill "$niri_pid" 2>/dev/null || true
      wait "$niri_pid" 2>/dev/null || true
      log "niri не поднял композитор — текстовый режим (denv)"
      exec ${denv} "$@"
    fi

    log "сессия niri поднята, noctalia стартует через spawn-at-startup"
    set +e
    wait "$niri_pid"
    rc=$?
    set -e
    log "niri завершился (rc=$rc) — greetd покажет логин"
    exit "$rc"
  ''
