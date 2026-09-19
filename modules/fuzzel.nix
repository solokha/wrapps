{ pkgs, ... }:
pkgs.writeShellScriptBin "fuzzel" ''
  theme="''${XDG_CONFIG_HOME:-$HOME/.config}/foot/themes/noctalia"
  config="$(mktemp)"
  trap 'rm -f "$config"' EXIT

  cat >"$config" <<'EOF'
  [main]
  font=JetBrainsMono Nerd Font:size=14
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
  EOF

  get() {
    awk -F= -v k="$1" '$1==k { gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); print $2; exit }' "$theme"
  }

  if [ -f "$theme" ]; then
    bg="$(get background)"
    fg="$(get foreground)"
    r0="$(get regular0)"
    r3="$(get regular3)"
    r4="$(get regular4)"
    b0="$(get bright0)"
    cat >>"$config" <<EOF
  [colors]
  background=''${bg}ee
  text=''${fg}ff
  prompt=''${r4}ff
  placeholder=''${b0}ff
  input=''${fg}ff
  match=''${r3}ff
  selection=''${r0}ff
  selection-text=''${fg}ff
  selection-match=''${r3}ff
  border=''${r4}ee
  EOF
  else
    cat >>"$config" <<'EOF'
  [colors]
  background=f2ecbcf2
  text=545464ff
  prompt=4d699bff
  placeholder=8a8980ff
  input=545464ff
  match=77713fff
  selection=1f1f28ee
  selection-text=545464ff
  selection-match=77713fff
  border=4d699bee
  EOF
  fi

  exec ${pkgs.fuzzel}/bin/fuzzel --config "$config" "$@"
''