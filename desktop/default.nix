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
    noctalia_config="$noctalia_config_dir/config.toml"
    noctalia_origin="$noctalia_config_dir/.origin"
    mkdir -p "$noctalia_config_dir"

    # Конфиг раскладываем не только когда его нет, иначе правка в флейке не
    # доезжает до машин, где конфиг уже разложен: guard «файла нет» вечно
    # оставляет старую сборку из /nix/store. `.origin` — копия того, что мы
    # положили в прошлый раз. Совпадает с ним — пользователь не трогал,
    # обновляем. Разошёлся — файл пользовательский, не трогаем.
    deploy_config() {
      # install, а не cp: файлы из /nix/store read-only, и cp тащит этот режим,
      # после чего конфиг нельзя ни перезаписать, ни отредактировать руками.
      if ! install -m 644 ${../noctalia/config.toml} "$noctalia_config"; then
        log "не удалось положить конфиг noctalia — продолжаем без него"
        return 0
      fi
      install -m 644 ${../noctalia/config.toml} "$noctalia_origin" 2>/dev/null || true
    }

    if [ ! -f "$noctalia_config" ]; then
      deploy_config
    elif [ ! -f "$noctalia_origin" ]; then
      # конфиг из прежней версии desktop, где .origin не вёлся — не знаем,
      # трогал ли его пользователь, поэтому прежнее содержимое сохраняем
      if install -m 644 "$noctalia_config" "$noctalia_config_dir/config.toml.bak"; then
        log "config.toml без .origin (прежний desktop) — прежнее содержимое в config.toml.bak"
      fi
      deploy_config
    elif [ "$(cat "$noctalia_config")" = "$(cat "$noctalia_origin")" ]; then
      deploy_config
    else
      log "config.toml изменён вручную — оставляю как есть"
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
