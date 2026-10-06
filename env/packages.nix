{pkgs}:
with pkgs; [
  nil
  nixd
  statix
  alejandra
  manix
  nix-inspect

  eza
  fd
  ripgrep
  zoxide
  fzf

  dua
  dust
  file
  unzip
  zip
  p7zip

  git
  lazygit
  jq
  htop
  btop
  pkgs.unstable.fastfetch
  wget
  killall

  atuin
  starship

  tmux

  sops
  age
  ssh-to-age
  openssh

  openssh-askpass

  age-plugin-fido2-hmac
  cryptsetup

  pkgs.unstable.nvd
]
