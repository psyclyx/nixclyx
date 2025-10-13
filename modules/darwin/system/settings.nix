{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.system.settings;
in
{
  options = {
    psyclyx.system.settings = {
      enable = lib.mkEnableOption "macOS system settings";
    };
  };

  config = lib.mkIf cfg.enable {
    system = {
      defaults = {
      NSGlobalDomain = {
        AppleShowAllFiles = true;
        AppleShowAllExtensions = true;
        NSAutomaticCapitalizationEnabled = false;
        NSAutomaticSpellingCorrectionEnabled = false;
        NSAutomaticDashSubstitutionEnabled = false;
        NSAutomaticInlinePredictionEnabled = false;
        NSAutomaticQuoteSubstitutionEnabled = false;
        NSAutomaticWindowAnimationsEnabled = false;
        NSDocumentSaveNewDocumentsToCloud = false;
        AppleWindowTabbingMode = "manual";
        NSNavPanelExpandedStateForSaveMode = true;
        NSNavPanelExpandedStateForSaveMode2 = true;
        NSScrollAnimationEnabled = false;
        NSWindowResizeTime = 0.01;
        NSWindowShouldDragOnGesture = true;
        "com.apple.trackpad.enableSecondaryClick" = true;
        "com.apple.swipescrolldirection" = false;
        _HIHideMenuBar = true; # TODO: move to swaybar
      };
      dock = {
        autohide = true;
        autohide-delay = 0.1;
        autohide-time-modifier = 0.1;
        magnification = false;
        mineffect = "scale";
        orientation = "bottom";
        showhidden = false;
        show-recents = false;
        tilesize = 48;
        wvous-tl-corner = 1;
        wvous-bl-corner = 1;
        wvous-tr-corner = 1;
        wvous-br-corner = 1;
      };
      finder = {
        CreateDesktop = false;
        FXEnableExtensionChangeWarning = false;
        NewWindowTarget = "Home";
        ShowPathbar = true;
        ShowStatusBar = true;
      };
      spaces = {
        spans-displays = true;
      };
      trackpad = {
        Clicking = false;
        TrackpadRightClick = true;
        TrackpadThreeFingerTapGesture = 0;
      };
      CustomUserPreferences = {
        "com.apple.AdLib".allowApplePersonalizedAdvertising = false;
      };
    };
      keyboard = {
        enableKeyMapping = true;
        remapCapsLockToEscape = true;
      };
    };
  };
}
