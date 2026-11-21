{
  pkgs,
  ...
}: let
  xpi = pkgs.runCommand "everforest-sync.xpi" {
    nativeBuildInputs = [pkgs.zip];
  } ''
    cd ${./firefox-theme-sync}
    zip -qr "$out" .
  '';

  host = pkgs.writeShellScriptBin "everforest-sync-host" ''
    exec ${pkgs.nodejs}/bin/node ${./firefox-theme-sync-host.js}
  '';
in {
  inherit xpi host;
}
