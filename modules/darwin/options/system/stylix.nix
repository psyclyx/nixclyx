{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.darwin.system.stylix;
in {
  options.psyclyx.darwin.system.stylix = {
    enable = lib.mkEnableOption "stylix config";
  };

  config = lib.mkIf cfg.enable {
    psyclyx.common.system.stylix.enable = true;
  };
}
