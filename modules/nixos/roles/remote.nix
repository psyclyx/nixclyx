{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.roles.remote;
in
{
  options = {
    psyclyx.roles.remote = {
      enable = lib.mkEnableOption "role for networking between hosts";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx = {
      services = {
        openssh.enable = lib.mkDefault true;
        tailscale.enable = lib.mkDefault true;
      };
    };
  };
}
