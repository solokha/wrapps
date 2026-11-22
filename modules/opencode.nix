{
  pkgs,
  inputs,
  ...
}:
inputs.nix-wrapper-modules.wrappers.opencode.wrap {
  inherit pkgs;

  package = pkgs.llm-agents.opencode2;
  binName = "opencode";

  settings = {
    "$schema" = "https://opencode.ai/config.json";
    autoupdate = false;
  };

  tui-settings = {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "matugen";
    mouse = true;
    diff_style = "auto";
  };
}
