{ pkgs, ... }:
pkgs.symlinkJoin {
  name = "nh-wrapped";
  paths = [ pkgs.nh ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/nh \
      --run '
        if [ -z "''${NH_FLAKE:-}" ]; then
          repo_root="$(${pkgs.git}/bin/git rev-parse --show-toplevel 2>/dev/null || true)"
          if [ -n "$repo_root" ]; then
            export NH_FLAKE="$repo_root"
          fi
        fi
      '
  '';
}
