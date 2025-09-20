{ config, lib, ... }:
let
  cfg = config.psyclyx.system.timezone;
in
{
  options = {
    psyclyx.system.timezone = {
      default = lib.mkOption {
        type = lib.types.str;
        default = "America/Los_Angeles";
        description = "Default timezone";
      };
      enable = lib.mkEnableOption "Timezone config";
    };
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = cfg.default;
  };
}
