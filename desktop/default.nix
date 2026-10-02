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

    noctalia_config_dir="''${XDG_CONFIG_HOME:-$HOME/.config}/noctalia"
    mkdir -p "$noctalia_config_dir"
    if [ ! -f "$noctalia_config_dir/config.toml" ]; then
      if ! cp ${../noctalia/config.toml} "$noctalia_config_dir/config.toml"; then
        log "не удалось положить конфиг noctalia — продолжаем без него"
      fi
    fi

    if [ -n "''${WAYLAND_DISPLAY:-}" ] || [ -n "''${DISPLAY:-}" ]; then
      log "запущено внутри ''${WAYLAND_DISPLAY:-$DISPLAY} — desktop требует чистый tty (greetd/логин)"
      exec ${shell} "$@"
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
