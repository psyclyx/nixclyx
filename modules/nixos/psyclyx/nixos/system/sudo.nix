{ config, lib, ... }:
let
  inherit (lib)
    mkEnableOption
    mkIf
    mkOption
    types
    ;
  cfg = config.psyclyx.nixos.system.sudo;
in
{
  options = {
    psyclyx.nixos.system.sudo = {
      enable = mkEnableOption "privilege escalation via sudo";
      timestampTimeout = mkOption {
        type = types.ints.unsigned;
        default = 30;
        description = "Timeout (in minutes) before asking for password again.";
      };
    };
  };

  config = mkIf cfg.enable {
    security.sudo = {
      extraConfig = ''
        Defaults        timestamp_timeout=${builtins.toString cfg.timestampTimeout}
      '';
    };
  };
}
