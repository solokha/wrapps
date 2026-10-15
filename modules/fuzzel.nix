{pkgs, ...}:
pkgs.writeShellScriptBin "fuzzel" ''
  config="$(mktemp)"
  trap 'rm -f "$config"' EXIT

  cat >"$config" <<EOF
  [main]
  font=FiraCode Nerd Font:size=14
  terminal=foot -e
  prompt="> "
  lines=10
  width=48
  horizontal-pad=18
  vertical-pad=14
  inner-pad=10
  icon-theme=Gruvbox-Plus-Dark
  dpi-aware=yes
  show-actions=yes
  layer=overlay

  include=''${XDG_CONFIG_HOME:-$HOME/.config}/fuzzel/themes/noctalia
  EOF

  exec ${pkgs.fuzzel}/bin/fuzzel --config "$config" "$@"
''
