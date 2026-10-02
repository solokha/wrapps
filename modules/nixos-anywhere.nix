{pkgs, ...}:
pkgs.symlinkJoin {
  name = "nixos-anywhere-lab";
  paths = [
    pkgs.nixos-anywhere
    pkgs.disko
    pkgs.env
    pkgs.nix
  ];
  meta.mainProgram = "nixos-anywhere";
}
