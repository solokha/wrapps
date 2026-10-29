{pkgs, ...}:
pkgs.wrapFirefox pkgs.firefox-esr-unwrapped {
  extraPolicies = {
    DisableTelemetry = true;
    DisableFirefoxStudies = true;
    DisablePocket = true;
    DisableFirefoxAccounts = true;
    DisableFeedbackCommands = true;
    DontCheckDefaultBrowser = true;
    OfferToSaveLogins = false;
    PasswordManagerEnabled = false;
    SearchSuggestEnabled = true;
    TranslateEnabled = true;

    ExtensionSettings = {
      "*" = {
        installation_mode = "blocked";
      };

      "uBlock0@raymondhill.net" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
      };

      "{446900e4-71c2-419f-a6a7-df9c091e268b}" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/bitwarden-password-manager/latest.xpi";
      };

      "{aecec67f-0d10-4fa7-b7c7-609a2db280cf}" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/violentmonkey/latest.xpi";
      };

      "jid0-adyhmvsP91nUO8pRv0Mn2VKeB84@jetpack" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/raindropio/latest.xpi";
      };

      "foxytab@eros.man" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/foxytab/latest.xpi";
      };

      "side-view@mozilla.org" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/side-view/latest.xpi";
      };

      "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/vimium-ff/latest.xpi";
      };

      "@testpilot-containers" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/multi-account-containers/latest.xpi";
      };

      "{0e5c8ff0-b54b-4bd1-b33e-d5e016e066f0}" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/file/5128466/everforest_dark_medium_theme-2.9.xpi";
      };

      "{08400cc9-1bf6-4e3e-b175-2d2650bc3104}" = {
        installation_mode = "force_installed";
        install_url = "https://addons.mozilla.org/firefox/downloads/file/4055906/everforest_light_official-2.0.xpi";
      };
    };

    FirefoxHome = {
      Search = true;
      TopSites = false;
      SponsoredTopSites = false;
      Highlights = false;
      Pocket = false;
      Snippets = false;
      SponsoredPocket = false;
    };

    UserMessaging = {
      ExtensionRecommendations = false;
      FeatureRecommendations = false;
      UrlbarInterventions = false;
      SkipOnboarding = true;
      MoreFromMozilla = false;
    };

    SearchEngines = {
      Default = "DuckDuckGo";
      Remove = ["Amazon.com" "Bing" "eBay" "Google" "Wikipedia (en)"];
    };

    Homepage = {
      URL = "about:blank";
      StartPage = "homepage";
      Locked = true;
    };
  };

  extraPrefs = ''
    lockPref("browser.startup.homepage", "about:blank");
    lockPref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
    lockPref("browser.tabs.inTitlebar", 1);
    lockPref("sidebar.revamp", true);
    lockPref("sidebar.verticalTabs", true);
    lockPref("sidebar.visibility", "always-show");
    lockPref("privacy.globalprivacycontrol.enabled", true);
    lockPref("privacy.globalprivacycontrol.functionality.enabled", true);
    lockPref("intl.accept_languages", "ru, en-US, en");

    // Встроенный перевод страниц: модели Bergamot считаются на машине, текст
    // страниц наружу не уходит; пара языков докачивается с Mozilla при первом
    // переводе. Автоперевода нет (`alwaysTranslateLanguages` не задан) —
    // панель только предлагается, переводить или читать как есть решаешь сам.
    // Русские страницы не предлагать. Обычный pref, а не lockPref: всё
    // переключается обратно из интерфейса.
    pref("browser.translations.enable", true);
    pref("browser.translations.automaticallyPopup", true);
    pref("browser.translations.neverTranslateLanguages", "ru");

    // Multi-Account Containers (@testpilot-containers): контейнеры — встроенная
    // фича, аддон лишь даёт интерфейс. Без этого pref'а аддон включает её сам,
    // но лучше явно.
    pref("privacy.userContext.enabled", true);

    // Закреплённые окна-«веб-приложения»: кнопка «Add tab to taskbar» в адресной
    // строке, каждой записи — свои домены в области видимости, на Linux
    // дополнительно создаётся .desktop-файл. На вертикальные табы
    // (sidebar.verticalTabs) не влияет — фичи независимы.
    // pref, а не lockPref: переключается обратно из интерфейса.
    pref("browser.taskbarTabs.enabled", true);

    // Схему tg:// Firefox сам обработать не может: сайту разрешено занять
    // только web+tg://, а Telegram Web себе его не регистрирует. Отдаём схему
    // системе — обработчик tg-web из этого же репозитория (modules/tg-web.nix).
    // Три pref'а — тот же набор, что у mailto в самом firefox.js:
    // external — схема обслуживается внешним приложением,
    // expose=false — не пытаться обработать её внутри,
    // warn-external=false — не спрашивать каждый раз «чем открыть».
    pref("network.protocol-handler.external.tg", true);
    pref("network.protocol-handler.expose.tg", false);
    pref("network.protocol-handler.warn-external.tg", false);

    // vimium из списка force_installed: показывать подсказки, не разворачивать
    // панели настроек, и не мешать раскладке.
    pref("extensions.vimiumc.showAdvanced", false);
    pref("extensions.vimiumc.ignoreKeyboardLayout", true);

    // Everforest Dark Medium по умолчанию; светлая тема — см. GUID
    // {08400cc9-1bf6-4e3e-b175-2d2650bc3104} (Everforest Light).
    pref("extensions.activeThemeID", "{0e5c8ff0-b54b-4bd1-b33e-d5e016e066f0}");
  '';
}
