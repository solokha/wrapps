{
  pkgs,
  inputs,
  ...
}:
inputs.nix-wrapper-modules.wrappers.atuin.wrap {
  inherit pkgs;

  settings = {
    update_check = false;
    auto_sync = false;

    stats.ignored_commands = ["cd" "ls"];
  };
}
