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
    TranslateEnabled = false;

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

    // vimium из списка force_installed: показывать подсказки, не разворачивать
    // панели настроек, и не мешать раскладке.
    pref("extensions.vimiumc.showAdvanced", false);
    pref("extensions.vimiumc.ignoreKeyboardLayout", true);
  '';
}
