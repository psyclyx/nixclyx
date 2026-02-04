{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.home.config.server;
in {
  options.psyclyx.home.config.server = {
    enable = lib.mkEnableOption "psyc server home config";
  };

  config = lib.mkIf cfg.enable {
    psyclyx.home.config.base.enable = true;
  };
}
