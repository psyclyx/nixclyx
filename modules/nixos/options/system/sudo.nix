{
  path = ["psyclyx" "nixos" "system" "sudo"];
  description = "privilege escalation via sudo";
  options = {lib, ...}: {
    timestampTimeout = lib.mkOption {
      type = lib.types.ints.unsigned;
      default = 30;
      description = "Timeout (in minutes) before asking for password again.";
    };
  };
  config = {cfg, ...}: {
    security.sudo = {
      extraConfig = ''
        Defaults        timestamp_timeout=${builtins.toString cfg.timestampTimeout}
      '';
    };
  };
}
