{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.home.config.darwin;
in {
  options.psyclyx.home.config.darwin = {
    enable = lib.mkEnableOption "psyc darwin home config";
  };

  config = lib.mkIf cfg.enable {
    psyclyx.home.config.base.enable = true;

    psyclyx.home.programs.kitty.enable = true;
  };
}
