# wrapps

Портативное десктоп-окружение, обёрнутые пакеты и оболочка для работы с ключами
(ssh / sops / age).

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

# Портативная оболочка (bash + git + hx + zellij + nh + sops/age/ssh)
nix run github:solokha/wrapps#env   # то же самое, что #shell / бинарь denv на PATH
nix run github:solokha/wrapps#shell
```

## Ключи в оболочке (`#env`)

При старте оболочка сама поднимает OpenSSH `ssh-agent` на сокете `~/.ssh/socket`
(агент GNOME/gcr не умеет security-ключи `sk`) и подгружает sk-ключ из `~/.ssh`:

```bash
# восстановить резидентный sk-ключ с FIDO2-токена (один раз, спросит PIN)
ssh-keygen -K -w ~/.ssh

# внутри env: SSH_AUTH_SOCK уже указывает на рабочий агент
keys                # вручную добавить sk-ключ в агент (функция оболочки)
ssh -T git@github.com
```

Пакеты `sops` / `age` / `age-keygen` / `ssh-to-age` — в PATH оболочки; путь к
age-ключам sops задаётся через `SOPS_AGE_KEY_FILE` (по умолчанию
`~/.config/sops/age/keys.txt`), поэтому `sops -d` расшифровывает секреты `infra`
прямо из live-ISO.

Подключение к NixOS-системе — см. `infra` (flake input `github:solokha/wrapps/dev`,
`nixpkgs.overlays = [ inputs.wrapps.overlays.default ]` + `inputs.wrapps.nixosModules.desktop`).

## Пакеты

Обёртки с конфигами: `niri`, `foot`, `fuzzel`, `firefox`, `kitty`, `zed`, `helix`,
`zellij`, `nh`, `noctalia` (noctalia берётся из warm unstable).