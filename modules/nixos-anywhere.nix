# Автоматическая переустановка хоста (nixos-anywhere) как отдельная обёртка.
#
# Отдельная точка входа, а не часть #env: nixos-anywhere нужен только при
# развёртывании (с live ISO), тянет qemu/kexec-инфраструктуру и в
# повседневной оболочке мешает. В #env его нет намеренно.
#
# Использование — из infra, см. infra/docs/deploy.md:
#   nixos-anywhere --flake .#rover --target-host root@192.168.77.65 \
#     --disko-format --use-remote-sudo
{ config, lib, pkgs, ... }:
let
  cfg = config.wrapps.nixosAnywhere;
  # Репо infra живёт рядом по умолчанию; путь переопределяется аргументом
  # или переменной окружения, чтобы не прибивать к машине.
  defaultInfraPath = builtins.getEnv "INFRA_PATH";
in {
  options.wrapps.nixosAnywhere = {
    enable = lib.mkEnableOption "nixos-anywhere: переустановка хоста по ssh с live ISO";

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = ''
        Дополнительные пакеты в PATH обёртки. Нужны для целей развёртывания,
        которых нет в самом nixos-anywhere: disko, наш env (sops/age/токены),
        nix-инструменты.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    wrapps.nixos-anywhere = pkgs.symlinkJoin {
      name = "nixos-anywhere-lab";
      paths = [ pkgs.nixos-anywhere ] ++ cfg.extraPackages;
      meta.mainProgram = "nixos-anywhere";
    };
  };
}
