# wrapps

Портативное десктоп-окружение и обёрнутые пакеты.

## Флейк

- `packages.*` — каждый пакет собирается отдельно и проверяется через
  `nix run .#<pkg>` на любой машине с Nix (без установки в систему).
- `overlays.default` — добавляет поверх nixpkgs:
  - `pkgs.wrapps.*` — обёрнутые пакеты (см. ниже),
  - `pkgs.wrapps.env` / `pkgs.env` — портативная оболочка,
  - `pkgs.wrapps.desktop` / `pkgs.desktop` — вход в сессию,
  - `pkgs.unstable` / `pkgs.master` — nixpkgs-unstable / nixpkgs-master.
- `nixosModules.desktop` — NixOS-модуль: greetd + запуск десктопа (`niri + noctalia`).
- `nixosModules.default` — добавляет в `environment.systemPackages` env, desktop, firefox, foot.

## Параметры

```bash
# Собрать/запустить всё (для любой Wayland-/tty-сессии)
nix run github:solokha/wrapps#desktop

# Портативная оболочка (bash + git + hx + zellij + nh + CLI-набор)
nix run github:solokha/wrapps#env
```

Подключение к NixOS-системе — см. `infra` (flake input `github:solokha/wrapps/dev`,
`nixpkgs.overlays = [ inputs.wrapps.overlays.default ]` + `inputs.wrapps.nixosModules.desktop`).

## Пакеты

Обёртки с конфигами: `niri`, `foot`, `fuzzel`, `firefox`, `kitty`, `zed`, `helix`,
`zellij`, `nh`, `noctalia` (noctalia берётся из warm unstable).