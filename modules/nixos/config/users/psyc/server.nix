{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.config.users.psyc.server;
in {
  options.psyclyx.nixos.config.users.psyc.server = {
    enable = lib.mkEnableOption "psyc server user";
  };

  config = lib.mkIf cfg.enable {
    psyclyx.nixos.config.users.psyc.base.enable = true;
    home-manager.users.psyc.psyclyx.home.config.server.enable = true;
  };
}
