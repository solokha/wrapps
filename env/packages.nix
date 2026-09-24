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

  # Из unstable
  pkgs.unstable.nvd
]
