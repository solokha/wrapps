{
  pkgs,
  lib,
  ...
}: let
  fetchCrx = {
    id,
    hash,
  }: let
    crx = pkgs.fetchurl {
      url = "https://clients2.google.com/service/update2/crx?response=redirect&prodversion=158.0.0.0&acceptformat=crx2,crx3&x=id%3D${id}%26uc";
      inherit hash;
    };
  in
    pkgs.runCommand "chromium-ext-${id}" {
      nativeBuildInputs = [pkgs.unzip];
    } ''
      ${pkgs.python3}/bin/python3 -c 'import struct,sys; d=open(sys.argv[1],"rb").read(); h=struct.unpack("<I",d[8:12])[0]; open(sys.argv[2],"wb").write(d[12+h:])' ${crx} ext.zip
      mkdir -p $out
      unzip -q ext.zip -d $out
    '';

  extensions = [
    (fetchCrx {
      id = "nngceckbapebfimnlniiiahkandclblb";
      hash = "sha256-W7/EQcarOCqGd7EzrqP8P/K67XzP5usbFhcbQpiTc/I=";
    })
    (fetchCrx {
      id = "ldgfbffkinooeloadekpmfoklnobpien";
      hash = "sha256-zHxhKB0Jq88rJWRxHruACBdq8fhDgtltMi2uoZ6MCiY=";
    })
    (fetchCrx {
      id = "dbepggeogbaibhgnhhndojpepiihcmeb";
      hash = "sha256-MZjCaqcZvkYt6lhQUPvtm4uAYo1X6oihE7q/UzTFUXw=";
    })
    (fetchCrx {
      id = "jinjaccalgkegednnccohejagnlnfdag";
      hash = "sha256-Q0QYHk7D80lXY+Xa3NV/1zOmwJlYmtws32nSzaDn1lM=";
    })
  ];

  uboLite = fetchCrx {
    id = "ddkjiahejlhfcafbddmgiahcphecmpfh";
    hash = "sha256-CQj0ttGaOPJoG9dG5Fl9eBjwg7s+LjzFU0tAfYlrB/0=";
  };

  loadPaths = lib.concatMapStringsSep "," toString extensions;
  uboName = builtins.baseNameOf (toString uboLite);
in
  pkgs.writeShellScriptBin "chromium" ''
    set -eu

    cache="''${XDG_CACHE_HOME:-$HOME/.cache}/chromium-extensions/${uboName}"
    if [ ! -d "$cache" ]; then
      mkdir -p "$(dirname "$cache")"
      cp -r ${uboLite} "$cache"
      chmod -R u+w "$cache"
    fi

    exec ${lib.getExe pkgs.ungoogled-chromium} --load-extension=${loadPaths},$cache "$@"
  ''
