# wrapps

[en](README.en.md)

Переносимое окружение NixOS и обёрнутые приложения.

## Быстрый старт

```bash
nix run github:solokha/wrapps/main#env
```

## Состав

- `env` — окружение с инструментами и обёрнутыми пакетами
- `shell` — интерактивная оболочка с окружением
- `denv` — прямой запуск окружения
- `desktop` — десктоп целиком
- `noctalia` — коллекция тем

## Пакеты

- Терминал: `foot`, `zellij`, `helix`
- Десктоп: `niri`, `fuzzel`, `zed`
- Браузер: `firefox`
- Инструменты: `git`, `lazygit`, `btop`, `eza`, `ripgrep`, `fzf`
- Агент: `opencode` (v2, из `llm-agents.nix`)

## FIDO2

Ключи FIDO2 используются для доступа по SSH. Окружение поднимает
`wrapps-agent` и подсказывает, когда требуется PIN.

Первый раз нужно восстановить ключи с токена:

```bash
mkdir -p ~/.ssh && cd ~/.ssh && ssh-keygen -K
```

`ssh-keygen -K` скачивает резидентные ключи, пишет обе половины в текущий
каталог и требует касания токена. Дальше `wrapps-ssh-config` подставляет их
в `~/.ssh/config`, если система их ещё не перечисляет сама.

Приватные ключи на диске — только handle-файлы (пустые), сам секрет остаётся
в токене.

## Использование

```bash
# Войти в окружение
nix run github:solokha/wrapps/main#env

# Запустить конкретный инструмент
nix run github:solokha/wrapps/main#env -- git status

# Десктоп
nix run github:solokha/wrapps/main#desktop
```

[English](README.en.md)