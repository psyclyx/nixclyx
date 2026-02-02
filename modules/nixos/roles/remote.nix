{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.roles.remote;
in {
  options = {
    psyclyx.nixos.roles.remote = {
      enable = lib.mkEnableOption "role for networking between hosts";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx = {
      nixos = {
        services = {
          openssh.enable = lib.mkDefault true;
          tailscale.enable = lib.mkDefault true;
        };
      };
    };
  };
}
