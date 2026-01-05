{ config, lib, ... }:
let
  cfg = config.psyclyx.nixos.system.timezone;
in
{
  options = {
    psyclyx.nixos.system.timezone = {
      enable = lib.mkEnableOption "Timezone config";
      default = lib.mkOption {
        type = lib.types.str;
        default = "America/Los_Angeles";
        description = "Default timezone";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    time.timeZone = cfg.default;
  };
}
