# wrapps

Портативное десктоп-окружение, обёрнутые пакеты и оболочка для работы с ключами
(ssh / sops / age). Nix-флейк, который работает на любой машине с Nix — установки
в систему не требует.

[English](README.en.md)

## Что внутри

| Пакет | Что это |
|---|---|
| `#env` | Портативная оболочка: bash, git, hx, nh, tmux, sops/age/ssh, промпт и история |
| `#desktop` | Вход в сессию: greetd + niri + noctalia |
| `#foot`, `#fuzzel` | Терминал и лаунчер с темой noctalia |
| `#niri`, `#noctalia` | Композитор и оболочка рабочего стола |
| `#firefox`, `#zed`, `#helix`, `#zellij` | Обёрнутые приложения |
| `#nh` | Обёртка NixOS-реконфигурации |
| `#nixos-anywhere` | Переустановка хоста, вызывается отдельно, не часть `#env` |

## Запуск

```bash
# Десктоп (нужен чистый tty — greetd или логин, не из-под другой сессии)
nix run github:solokha/wrapps#desktop

# Оболочка
nix run github:solokha/wrapps#env      # то же, что #shell / #denv
nix run github:solokha/wrapps#shell

# Один пакет
nix run github:solokha/wrapps#foot
```

Из локального клона — `nix run .#env`, офлайн.

## Подключение к NixOS

Флейк подключается как вход, оверлей добавляет пакеты в `pkgs`:

```nix
inputs.wrapps.url = "github:solokha/wrapps/dev";
nixpkgs.overlays = [ inputs.wrapps.overlays.default ];
inputs.wrapps.nixosModules.desktop
```

Ветка `dev` обязательна — `main` пустая.

## Ключи

`#env` поднимает свой `ssh-agent` и умеет работать с FIDO2-ключами в графической
сессии. Команды в PATH оболочки: `wrapps-agent`, `wrapps-ssh-config`.

```bash
# один раз: восстановить резидентные ключи с токена
cd ~/.ssh && ssh-keygen -K

# в сессии агент уже поднят
eval "$(wrapps-agent)"
wrapps-ssh-config
ssh -T git@github.com
```

Подробности про FIDO2, keystore и DR — в приватной документации `infra`
(`docs/wrapps-input.md`, `docs/rollback-keystore.md`).
