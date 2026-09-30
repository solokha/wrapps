{ pkgs }:
with pkgs; [
  # Nix
  nil nixd statix alejandra manix nix-inspect
  # Навигация
  eza fd ripgrep zoxide fzf
  # Файлы
  dua dust file unzip zip p7zip
  # Dev
  git lazygit jq htop btop wget killall
  # Shell-инструменты
  atuin starship

  # Ключи
  sops age ssh-to-age openssh

  # Диалог PIN для ssh-agent. Агент зовёт SSH_ASKPASS, только если у него нет
  # терминала: из графической сессии терминала нет, с live ISO в консоли есть,
  # и агент спрашивает сам. Поэтому askpass нужен ровно для первого случая.
  # Именно openssh-askpass, а не pinentry: pinentry говорит по протоколу
  # Assuan (диалог gpg-агента) и как askpass зависает.
  openssh-askpass

  # Аварийное восстановление: LUKS-keystore + возраст-идентичности с
  # FIDO2-токена (ctap2 hmac-secret). Без плагина sops не прочитает
  # secrets/*.yaml — идентичности лежат на токенах, не в файлах.
  age-plugin-fido2-hmac cryptsetup

  # Из unstable
  pkgs.unstable.nvd
]
