{ pkgs, inputs, self }:
let
  system = pkgs.stdenv.hostPlatform.system;
  niri = "${self.packages.${system}.niri}/bin/niri";
  noctalia = "${self.packages.${system}.noctalia}/bin/noctalia";
  denv = "${self.packages.${system}.env}/bin/denv";
  shell = "${self.packages.${system}.env}/bin/shell";
in
pkgs.writeShellScriptBin "desktop" ''
  set -euo pipefail

  log() { printf 'desktop: %s\n' "$*"; }

  # Подготовка конфига noctalia (тема/бар/обои), если его ещё нет.
  noctalia_config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/noctalia"
  mkdir -p "$noctalia_config_dir"
  if [ ! -f "$noctalia_config_dir/config.toml" ]; then
    if ! cp ${../noctalia/config.toml} "$noctalia_config_dir/config.toml"; then
      log "не удалось положить конфиг noctalia — продолжаем без него"
    fi
  fi

  # Запуск из-под уже существующей графической сессии (X или чужой Wayland):
  # niri не сможет захватить DRM-мастер — не пытаемся, сразу честный текстовый режим.
  if [ -n "''${WAYLAND_DISPLAY:-}" ] || [ -n "''${DISPLAY:-}" ]; then
    log "запущено внутри ''${WAYLAND_DISPLAY:-$DISPLAY} — desktop требует чистый tty (greetd/логин)"
    exec ${shell} "$@"
  fi

  # Каскад fallback: niri (+noctalia через spawn-at-startup) → denv → понятное сообщение.
  # После старта niri ждём появления нового wayland-сокета: это признак того, что
  # композитор реально поднялся, а не упал на инициализации.
  rt="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
  before="$(find "$rt" -maxdepth 1 -name 'wayland-*' -type s 2>/dev/null | sort)"

  ${niri} --session &
  niri_pid=$!

  ok=1
  for _ in $(seq 1 30); do
    sleep 0.5
    new="$(find "$rt" -maxdepth 1 -name 'wayland-*' -type s 2>/dev/null | sort)"
    if [ -n "$before" ]; then
      if [ "$new" != "$before" ] && [ -n "$new" ]; then ok=0; break; fi
    elif [ -n "$new" ]; then
      ok=0; break
    fi
    # niri вышел раньше, чем поднял композитор — сразу в fallback.
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