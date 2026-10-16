{pkgs, ...}:
# OpenCode 2 из llm-agents ставится как `opencode2`, чтобы не конфликтовать с
# v1 из nixpkgs. Нам нужен ровно один бинарь и под именем `opencode` — его
# ждут и harness (~/.config/opencode), и сохранённое состояние в HOME.
#
# Никаких файлов в ~/.config/opencode обёртка не кладёт: этот каталог
# принадлежит harness (симлинки install.sh) и персистится в preservation infra.
pkgs.symlinkJoin {
  name = "opencode";
  paths = [pkgs.llm-agents.opencode2];
  postBuild = ''
    ln -sf opencode2 $out/bin/opencode
  '';
  meta.mainProgram = "opencode";
}
