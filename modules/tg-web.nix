{
  pkgs,
  self,
  ...
}: let
  system = pkgs.stdenv.hostPlatform.system;

  # Обёрнутый firefox из этого же репозитория: тот самый, что стоит в
  # systemPackages и в окне-веб-приложении Telegram. Путь в store, а не
  # /run/current-system/sw/bin/firefox — обработчик не должен зависеть от того,
  # как собран системный профиль конкретного хоста.
  firefox = "${self.packages.${system}.firefox}/bin/firefox";

  # Схему tg:// держит это скрипт, а не Firefox (см. комментарий к pref'ам в
  # modules/firefox.nix). Веб-клиент принимает тот же диплинк в виде
  # https://web.telegram.org/a/#?tgaddr=<tg://…> и читает хеш один раз при
  # загрузке страницы, поэтому открываем новой вкладкой, а не подменой хеша в
  # уже открытой.
  #
  # Хеш — это одна строка запроса, поэтому значение кодируем целиком: без этого
  # '&' и '+' внутри tg://-ссылки разрезали бы её на лишние параметры
  # (URLSearchParams в Telegram Web трактует '+' как пробел).
  tg-web = pkgs.writeShellScriptBin "tg-web" ''
    set -eu

    case "''${1:-}" in
      "")
        # Запуск без ссылки: кнопка в меню, ручной вызов. Открываем клиент.
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
