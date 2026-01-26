{ config, lib, ... }:
let
  cfg = config.psyclyx.nixos.system.locale;
in
{
  options = {
    psyclyx.nixos.system.locale = {
      enable = lib.mkEnableOption "Locale config";
      default = lib.mkOption {
        type = lib.types.str;
        default = "en_US.UTF-8";
        description = "Default locale.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    i18n.defaultLocale = cfg.default;
  };
}
