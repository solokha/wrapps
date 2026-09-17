{ pkgs, inputs, ... }:
inputs.nix-wrapper-modules.lib.wrapPackage {
  inherit pkgs;
  package = pkgs.helix;
  flags."--config" = pkgs.writeText "helix-config.toml" ''
    theme = "noctalia"

    [editor]
    line-number = "relative"
    mouse = false
    bufferline = "multiple"
    auto-save = true

    [editor.cursor-shape]
    insert = "bar"
    normal = "block"
    select = "underline"

    [editor.file-picker]
    hidden = false

    [editor.statusline]
    left   = ["mode", "spinner", "file-name"]
    center = []
    right  = ["diagnostics", "selections", "position", "file-encoding"]

    [keys.normal]
    Z = { Q = ":quit!", Z = ":x" }
  '';
}
