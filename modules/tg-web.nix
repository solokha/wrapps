{
  pkgs,
  self,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;

  firefox = "${self.packages.${system}.firefox}/bin/firefox";

  tg-web = pkgs.writeShellScriptBin "tg-web" ''
    set -eu

    case "''${1:-}" in
      "")
        exec ${firefox} -new-tab https://web.telegram.org/a/
        ;;
    esac

    encoded="$(printf '%s' "$1" | ${pkgs.jq}/bin/jq -sRr @uri)"
    exec ${firefox} -new-tab "https://web.telegram.org/a/#?tgaddr=$encoded"
  '';
in
  pkgs.makeDesktopItem {
    name = "tg-web";
    desktopName = "Telegram Web";
    comment = "Обработчик ссылок tg:// — открывает их в Telegram Web";
    exec = "${tg-web}/bin/tg-web %u";
    mimeTypes = ["x-scheme-handler/tg"];
    categories = ["Network"];
    terminal = false;
    noDisplay = true;
  }
