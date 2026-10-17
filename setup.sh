#!/usr/bin/env bash
# Первичная настройка на чужом хосте или live-ISO.
#
#   curl -fsSLO https://raw.githubusercontent.com/solokha/wrapps/main/setup.sh
#   bash setup.sh
#
# Закрывает три вещи, которых на чистой системе нет:
#
#   1. nix-command и flakes. Свежий ISO или чужой хост их может не разрешать, а
#      запуск `nix run github:solokha/wrapps/main#env` без них падает с
#      «experimental Nix feature 'nix-command' is disabled». Включаем их для
#      своих вызовов nix через NIX_CONFIG — /etc/nix/nix.conf не трогаем.
#   2. Резидентные ключи FIDO2. Приватных ключей на диске нет вовсе: они лежат
#      на токене (в ~/.ssh только handle-заглушки). `ssh-keygen -K` скачивает их
#      обратно с токена; нужен PIN и касание.
#   3. Окружение. Вход в `env` (denv) поднимает агент и подкладывает ключи в
#      ~/.ssh/config — ssh не угадывает имена FIDO2-токенов: в списке IdentityFile
#      по умолчанию есть только id_ecdsa_sk, без суффикса _rk_<токен>.
#
# Скрипт идемпотентен: повторный запуск ничего не ломает и не пересоздаёт уже
# восстановленные ключи.
set -euo pipefail

# 1. nix-command/flakes -----------------------------------------------------
if ! nix config show experimental-features 2>/dev/null | grep -q flakes; then
  export NIX_CONFIG="experimental-features = nix-command flakes
${NIX_CONFIG:-}"
fi

# 2. резидентные ключи FIDO2 -------------------------------------------------
have_key=0
compgen -G "$HOME/.ssh/id_ecdsa_sk*"    >/dev/null 2>&1 && have_key=1
compgen -G "$HOME/.ssh/id_ed25519_sk*"  >/dev/null 2>&1 && have_key=1

if [ "$have_key" = 0 ]; then
  # Токен виден как hidraw-устройство с HID_NAME=…FIDO (та же проверка, что в env).
  if ! grep -lqiE 'HID_NAME=.*FIDO' /sys/class/hidraw/hidraw*/device/uevent 2>/dev/null; then
    printf 'setup: FIDO2-токен не виден.\n' >&2
    printf 'setup: вставь токен — резидентные ключи лежат только на нём.\n' >&2
    exit 1
  fi

  printf 'setup: восстанавливаю резидентные ключи с токена (PIN и касание)…\n' >&2
  mkdir -p "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"
  # ssh-keygen -K пишет обе половины в ТЕКУЩИЙ каталог, поэтому заходим в ~/.ssh;
  # на чужом хосте ssh-keygen может отсутствовать — берём из nixpkgs.
  (
    cd "$HOME/.ssh"
    if command -v ssh-keygen >/dev/null; then
      ssh-keygen -K
    else
      nix shell nixpkgs#openssh -c ssh-keygen -K
    fi
  )
fi

# 3. окружение ---------------------------------------------------------------
exec nix run github:solokha/wrapps/main#env
