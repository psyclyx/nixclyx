{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;

  cfg = config.psyclyx.nixos.system.timezone;
in
{
  options = {
    psyclyx.nixos.system.timezone = {
      enable = mkEnableOption "Timezone config";
      default = mkOption {
        type = types.str;
        default = "America/Los_Angeles";
        description = "Default timezone";
      };
    };
  };

  config = mkIf cfg.enable {
    time.timeZone = cfg.default;
  };
}
