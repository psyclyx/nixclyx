{nixclyx, lib, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "system" "locale"];
  description = "Locale config";
  options = {
    default = lib.mkOption {
      type = lib.types.str;
      default = "en_US.UTF-8";
      description = "Default locale.";
    };
  };
  config = {cfg, ...}: {
    i18n.defaultLocale = cfg.default;
  };
} args
