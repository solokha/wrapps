# Автоматическая переустановка хоста (nixos-anywhere) как отдельная обёртка.
#
# Отдельная точка входа, а не часть #env: nixos-anywhere нужен только при
# развёртывании (с live ISO), тянет qemu/kexec-инфраструктуру, и в
# повседневной оболочке мешает. В #env его нет намеренно.
#
# Вызывается точечно, из infra — см. infra/docs/deploy.md:
#   nixos-anywhere --flake .#rover --target-host root@192.168.77.65 \
#     --disko-format --use-remote-sudo
{ pkgs, ... }:
pkgs.symlinkJoin {
  name = "nixos-anywhere-lab";

  paths = [
    pkgs.nixos-anywhere
    # Цели развёртывания, которых нет в самом nixos-anywhere: разметка диска
    # и окружение с sops/age/FIDO2-плагином для доступа к секретам инфры.
    pkgs.disko
    pkgs.env
  ];

  meta.mainProgram = "nixos-anywhere";
}
