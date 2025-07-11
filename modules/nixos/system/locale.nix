{ config, lib, ... }:
let
  cfg = config.psyclyx.system.locale;
in
{
  options = {
    psyclyx = {
      system = {
        locale = {
          default = lib.mkOption {
            type = lib.types.str;
            default = "en_US.UTF-8";
            description = "Default locale.";
          };
        };
      };
    };
  };

  config = {
    i18n = {
      defaultLocale = cfg.default;
    };
  };
}
