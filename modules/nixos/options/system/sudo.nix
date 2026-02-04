{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.system.sudo;
in {
  options = {
    psyclyx.nixos.system.sudo = {
      enable = lib.mkEnableOption "privilege escalation via sudo";
      timestampTimeout = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 30;
        description = "Timeout (in minutes) before asking for password again.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    security.sudo = {
      extraConfig = ''
        Defaults        timestamp_timeout=${builtins.toString cfg.timestampTimeout}
      '';
    };
  };
}
