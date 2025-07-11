{ config, lib, ... }:
let
  cfg = lib.psyclyx.system.sudo;
in
{
  options = {
    psyclyx = {
      system = {
        sudo = {
          enable = lib.mkEnableOption "Configure sudo through psyclyx module.";
          timestampTimeout = lib.mkOption {
            type = lib.types.ints.unsigned;
            default = 30;
            description = "Timeout (in minutes) before asking for password again.";
          };
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    security = {
      sudo = {
        extraConfig = lib.mkIf ''
          Defaults        timestamp_timeout=${cfg.timestampTimeout}
        '';
      };
    };
  };
}
