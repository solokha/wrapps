{
  pkgs,
  inputs,
  ...
}:
# config.toml остаётся единственным источником настроек, но теперь читается
# как данные и передаётся wrapper-модулю. Он генерирует settings.toml в store
# и выставляет NOCTALIA_CONFIG_HOME, поэтому копировать файл в ~/.config больше
# не нужно.
inputs.nix-wrapper-modules.wrappers.noctalia.wrap {
  inherit pkgs;
  settings = builtins.fromTOML (builtins.readFile ./config.toml);
}
