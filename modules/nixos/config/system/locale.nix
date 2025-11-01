{ config, lib, ... }:
let
  cfg = config.psyclyx.system.locale;
in
{
  options = {
    psyclyx.system.locale = {
      default = lib.mkOption {
        type = lib.types.str;
        default = "en_US.UTF-8";
        description = "Default locale.";
      };
      enable = lib.mkEnableOption "Locale config";
    };
  };

  config = lib.mkIf cfg.enable {
    i18n.defaultLocale = cfg.default;
  };
}
