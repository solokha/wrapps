{
  pkgs,
  inputs,
  ...
}:
inputs.nix-wrapper-modules.wrappers.tmux.wrap {
  inherit pkgs;

  baseIndex = 0;
  paneBaseIndex = 0;
  mouse = true;
  historyLimit = 50000;
  escapeTime = 500;
  disableConfirmationPrompt = false;

  configAfter = ''
    source-file -q "$HOME/.config/tmux/themes/noctalia.conf"
  '';
}
