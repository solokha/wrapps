{ pkgs, inputs, self }:
let
  system = pkgs.stdenv.hostPlatform.system;
  niri = "${self.packages.${system}.niri}/bin/niri";
  noctalia = "${self.packages.${system}.noctalia}/bin/noctalia";
in
pkgs.writeShellScriptBin "desktop" ''
  set -e

  # Если запускаемся из-под уже работающего wayland-композитора — чистим
  # окружение, чтобы niri поднял СВОЮ композиционную сессию, а не пытался
  # наследовать чужой WAYLAND_DISPLAY (иначе ввод/фокус летит в родителя).
  if [ -n "''${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
    unset WAYLAND_DISPLAY DISPLAY XDG_SESSION_TYPE XDG_CURRENT_DESKTOP
    # новый сингулярный bus для сессии (иначе — чужая D-Bus-шина)
    exec dbus-run-session -- ${niri}
  fi

  systemctl --user import-environment \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_TYPE \
    DISPLAY 2>/dev/null || true

  dbus-update-activation-environment --systemd \
    WAYLAND_DISPLAY \
    XDG_CURRENT_DESKTOP \
    XDG_SESSION_TYPE \
    DISPLAY 2>/dev/null || true

  # Копируем конфиг noctalia, если его нет
  NOCTALIA_CONFIG_DIR="$HOME/.config/noctalia"
  mkdir -p "$NOCTALIA_CONFIG_DIR"
  if [ ! -f "$NOCTALIA_CONFIG_DIR/config.toml" ]; then
    cp ${../noctalia/config.toml} "$NOCTALIA_CONFIG_DIR/config.toml"
  fi

  # Запускаем noctalia в фоне
  ${noctalia} &

  # Запускаем niri как сессию
  exec ${niri} --session
''