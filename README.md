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

В `#env` есть четыре команды про ключи, все в PATH оболочки: `wrapps-agent`
(поднять агента, вывод для `eval`), `wrapps-keys` (загрузить sk-ключи),
`gitauth` (то и другое одной строкой), `gitsetup` (конфиг git там, где нет
системного). Подробности — ниже, в разделе про ключи.

## Origin

Репозиторий публичный, `origin` — по SSH:
```
git@github.com:solokha/wrapps.git      # ветка dev
```

Ветка `dev` — рабочая; `main` пустая и не используется. `infra` подключает
этот репозиторий как вход флейка (`github:solokha/wrapps/dev`), ревизия
зафиксирована в его `flake.lock`.

## Параметры

```bash
# Собрать/запустить всё (для любой Wayland-/tty-сессии)
nix run github:solokha/wrapps#desktop

# Портативная оболочка (bash + git + hx + zellij + nh + sops/age/ssh)
nix run github:solokha/wrapps#env   # то же самое, что #shell / бинарь denv на PATH
nix run github:solokha/wrapps#shell
```

## Ключи в оболочке (`#env`)

Оболочка поднимает **свой** `ssh-agent` на сокете
`$XDG_RUNTIME_DIR/wrapps-agent.sock` и подгружает sk-ключи из `~/.ssh`. Свой
сокет, а не системный: агент, поднятый без `SSH_ASKPASS` в окружении, на FIDO2
отвечает `agent refused operation`, и это выглядит как «подпись невозможна».

```bash
# восстановить резидентные sk-ключи с FIDO2-токенов (один раз, спросит PIN).
# -K пишет файлы в текущий каталог, поэтому сначала cd.
cd ~/.ssh && ssh-keygen -K

# внутри env агент уже поднят и ключи загружены; вручную — только если нужно
wrapps-keys                # добавить sk-ключи в агент (пропускает уже загруженные)
eval "$(gitauth)"          # то же: агент + ключи, три переменные для eval
ssh -T git@github.com
```

`wrapps-keys` загружает **один** sk-ключ: каждый `ssh-add` на таком ключе — это
один запрос PIN, а лишние ключи всё равно не нужны, потому что GitHub ходит по
`~/.ssh/config` с `IdentitiesOnly` и одним `IdentityFile`. Ключ грузит сам
`wrapps-agent` при подъёме агента, так что отдельно вызывать не надо; руками
это нужно, если агент поднят, а ключей в нём нет. Все ключи — осознанно:

```bash
WRAPPS_ALL_SK_KEYS=1 wrapps-keys                      # оба токена
WRAPPS_SK_KEY=~/.ssh/id_ecdsa_sk_rk_solo@clone wrapps-keys   # ровно этот
```

Агент переподнимается, если изменилось условие для подписи: с консоли
(`SSH_ASKPASS` не задаётся) на графическую сессию и обратно. Старый агент,
поднятый без `SSH_ASKPASS`, остаётся живым и с ключами — `ssh-add -l`
покажет их, но подписывать он не сможет, поэтому `ours()` сверяет не только pid
и сокет, но и askpass, с которым агент был запущен (вторая строка pid-файла).

### Где спрашивается PIN

Агент без терминала (из графической сессии, из запуска агента) сам зовёт
`SSH_ASKPASS`. `wrapps-agent` ставит туда штатный `openssh-askpass` из nixpkgs
(`libexec/gtk-ssh-askpass`, GTK3) — окно с PIN. Свой диалог не пишется:
askpass-протокол — приглашение в `argv[1]`, секрет в stdout — это ровно то, что
делает `openssh-askpass`. `pinentry` не подходит: это диалог gpg-агента, он
говорит по Assuan и в этой роли зависает.

Без дисплея `SSH_ASKPASS` намеренно **не** задаётся: с консоли live ISO терминал
есть, и агент спрашивает сам. Задать принудительно можно переменными
`WRAPPS_AGENT_SOCK` (путь к сокету) и `WRAPPS_ASKPASS` (свой бинарь).

### Подпись коммитов и push

`/etc/gitconfig` на NixOS-хостах уже настраивает `gpg.format=ssh`, `commit.gpgsign`
и `user.signingKey` — это делает `infra` (см. `modules/services/git.nix`), руками
ничего делать не нужно. На чужих хостах и live ISO системного конфига нет:

```bash
gitsetup                  # gpg.format=ssh, gpgsign, signingKey, ~/.ssh/config
```

`gitsetup` настраивает только то, чего нет: если системный `gpg.format` уже
`ssh`, скрипт ничего не меняет. `~/.ssh/config` создаётся, только если его нет,
и никогда не перезаписывает существующий — в нём может быть что-то ещё, кроме
GitHub. `user.name` и `user.email` скрипт не выдумывает: без них git commit
не пройдёт, и он об этом говорит.

Пакеты `sops` / `age` / `age-keygen` / `ssh-to-age` — в PATH оболочки; путь к
age-ключам sops задаётся через `SOPS_AGE_KEY_FILE` (по умолчанию
`~/.config/sops/age/keys.txt`), поэтому `sops -d` расшифровывает секреты `infra`
прямо из live-ISO.

Подключение к NixOS-системе — см. `infra` (flake input `github:solokha/wrapps/dev`,
`nixpkgs.overlays = [ inputs.wrapps.overlays.default ]` + `inputs.wrapps.nixosModules.desktop`).

## Пакеты

Обёртки с конфигами: `niri`, `foot`, `fuzzel`, `firefox`, `kitty`, `zed`, `helix`,
`zellij`, `nh`, `noctalia` (noctalia берётся из warm unstable).