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

В `#env` есть две команды про ключи, обе в PATH оболочки: `wrapps-agent`
(поднять агента, вывод для `eval`) и `wrapps-ssh-config` (блок в
`~/.ssh/config` для хостов без системного ssh_config). Подробности — ниже, в
разделе про ключи.

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
`$XDG_RUNTIME_DIR/wrapps-agent.sock` и грузит в него один sk-ключ из `~/.ssh`.
Свой сокет, а не системный: агент, поднятый без `SSH_ASKPASS` в окружении, на
FIDO2 отвечает `agent refused operation`, и это выглядит как «подпись
невозможна». Ключ выбирает сам `wrapps-agent`, отдельно звать нечего.

```bash
# восстановить резидентные sk-ключи с FIDO2-токенов (один раз, спросит PIN).
# -K пишет файлы в текущий каталог, поэтому сначала cd.
cd ~/.ssh && ssh-keygen -K

# внутри env агент уже поднят и ключ загружен
eval "$(wrapps-agent)"     # если шелл открыт до установки wrapps
ssh -T git@github.com
```

Грузится один ключ, потому что каждый `ssh-add` на sk-ключе — это запрос к
токену, а второй токен всё равно не нужен: хост идёт по конфигу с
`IdentitiesOnly` и одним `IdentityFile`.

Агент переподнимается, если изменилось условие для подписи: с консоли
(`SSH_ASKPASS` не задаётся) в графическую сессию и обратно. Старый агент,
поднятый без `SSH_ASKPASS`, остаётся живым и с ключами — `ssh-add -l`
покажет их, но подписывать он не сможет, поэтому `usable()` сверяет не только
pid и сокет, но и диалог, с которым агент был запущен (вторая строка
pid-файла). Проверить, какой агент достаётся шеллу:

```bash
echo "$SSH_AUTH_SOCK"     # ожидается $XDG_RUNTIME_DIR/wrapps-agent.sock
```

Если там `~/.ssh/socket`, шелл открыт до установки wrapps: `eval "$(wrapps-agent)"`
или новый `#env`.

### Где спрашивается PIN

Агент без терминала (в графической сессии) сам зовёт `SSH_ASKPASS`. Туда
ставится штатный `openssh-askpass` из nixpkgs (`libexec/gtk-ssh-askpass`, GTK3) —
окно с PIN. Свой диалог не пишется: askpass-протокол — приглашение в `argv[1]`,
секрет в stdout — это ровно то, что делает `openssh-askpass`. `pinentry` не
подходит: это диалог gpg-агента, он говорит по Assuan и в этой роли зависает.
`wrapps-askpass` между агентом и диалогом отвечает только на вопрос
`Confirm user presence` — на него `y`, потому что настоящая проверка присутствия
это касание токена; всё остальное уходит в диалог без изменений.

Без дисплея `SSH_ASKPASS` намеренно **не** задаётся: с консоли live ISO терминал
есть, и агент спрашивает сам.

Счётчика попыток PIN нет, и это осознанно. Скрипт получает строку и отдаёт её,
а верный PIN или нет — вопрос токена: отсюда это не узнать. Счётчик запросов
считал бы и успешные, отказывая после трёх нормальных подписей, то есть давал
бы ложную защиту. Остаток попыток виден в меню самого токена; читать его
программно нечем — `fido2-token -L` показывает вендора и продукт, `ykman` этот
токен не видит.

### Ключи для ssh: `~/.ssh/config`

ssh не угадывает имена ключей с FIDO2-токенов: в списке `IdentityFile` по
умолчанию есть только `id_ecdsa_sk`, а файл называется
`id_ecdsa_sk_rk_solo@clone`. Без явного блока серверу не предлагается ничего и
ssh уходит в пароль.

```bash
wrapps-ssh-config         # дописать блок Host * в ~/.ssh/config
ssh -G host | grep -E '^(identitiesonly|identityfile) '
```

`wrapps-ssh-config` не трогает свой блок повторно (по маркеру) и только дополняет
чужой конфиг, ничего не перезаписывая. Блок нужен на live ISO и чужих хостах,
где нет `/etc/ssh/ssh_config`. На NixOS-хостах тот же блок лежит в системном
конфиге (`infra`, `modules/services/git.nix`), и `~/.ssh/config` там не нужен.
Если он остался с прошлых запусков, ключ в `ssh -G` будет Listed дважды: ssh
складывает `IdentityFile` из всех совпавших блоков, а не перезаписывает. На
работу это не влияет, лишнюю копию можно убрать.

### Подпись коммитов и push

`/etc/gitconfig` на NixOS-хостах настраивает `gpg.format=ssh`, `commit.gpgsign`
и `user.signingKey` — это делает `infra` (см. `modules/services/git.nix`). На
живом ISO и чужих хостах системного конфига нет, там два значения руками:

```bash
git config --global gpg.format ssh
git config --global user.signingKey ~/.ssh/id_ecdsa_sk_rk_solo@clone
```

`user.name` и `user.email` тоже нужны, но это уже про git, а не про wrapps.

Пакеты `sops` / `age` / `age-keygen` / `ssh-to-age` — в PATH оболочки; путь к
age-ключам sops задаётся через `SOPS_AGE_KEY_FILE` (по умолчанию
`~/.config/sops/age/keys.txt`), поэтому `sops -d` расшифровывает секреты `infra`
прямо из live-ISO.

Подключение к NixOS-системе — см. `infra` (flake input `github:solokha/wrapps/dev`,
`nixpkgs.overlays = [ inputs.wrapps.overlays.default ]` + `inputs.wrapps.nixosModules.desktop`).

## Пакеты

Обёртки с конфигами: `niri`, `foot`, `fuzzel`, `firefox`, `kitty`, `zed`, `helix`,
`zellij`, `nh`, `noctalia` (noctalia берётся из warm unstable).