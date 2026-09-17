{ pkgs, ... }:
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
      Remove = [ "Amazon.com" "Bing" "eBay" "Google" "Wikipedia (en)" ];
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
  '';
}
