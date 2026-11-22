{
  pkgs,
  ...
}: let
  darkreader = pkgs.fetchurl {
    url = "https://github.com/darkreader/darkreader/releases/download/v4.9.135/darkreader-chrome-mv3.zip";
    hash = "sha256-bFm6EflzP28bpC55ET4r92TEH51QEDtSevc29V+8z0c=";
  };

  extension = pkgs.runCommand "darkreader-chromium" {
    nativeBuildInputs = [pkgs.unzip];
  } ''
    mkdir -p $out
    unzip -q ${darkreader} -d $out
  '';
in
  pkgs.symlinkJoin {
    name = "ungoogled-chromium-darkreader";
    paths = [pkgs.ungoogled-chromium];
    nativeBuildInputs = [pkgs.makeWrapper];
    meta.mainProgram = "chromium";
    postBuild = ''
      wrapProgram $out/bin/chromium --add-flags "--load-extension=${extension}"
    '';
  }
