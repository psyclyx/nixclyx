{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.psyclyx.nixos.system.locale;
in
{
  options = {
    psyclyx.nixos.system.locale = {
      enable = mkEnableOption "Locale config";
      default = mkOption {
        type = types.str;
        default = "en_US.UTF-8";
        description = "Default locale.";
      };
    };
  };

  config = mkIf cfg.enable {
    i18n.defaultLocale = cfg.default;
  };
}
