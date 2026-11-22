{pkgs, ...}:
pkgs.symlinkJoin {
  name = "opencode";
  paths = [pkgs.llm-agents.opencode2];
  postBuild = ''
    ln -sf opencode2 $out/bin/opencode
  '';
  meta.mainProgram = "opencode";
}
