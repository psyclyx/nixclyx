{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.config.roles.server;
in {
  options.psyclyx.nixos.config.roles.server = {
    enable = lib.mkEnableOption "server NixOS role";
  };

  config = lib.mkIf cfg.enable {
    psyclyx.nixos.config = {
      roles.base.enable = true;
      users.psyc.server.enable = true;
    };
  };
}
