{pkgs, ...}:
# GUI-клиент OpenCode 2 из llm-agents. Пакет уже содержит .desktop и иконки,
# поэтому обёртка не нужна. Бинарь называется opencode2-desktop и не конфликтует
# с TUI `opencode` из modules/opencode.nix.
pkgs.llm-agents.opencode2-desktop
