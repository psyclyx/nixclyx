{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.nixos.system.stylix;
in {
  options = {
    psyclyx.nixos.system.stylix = {
      enable = lib.mkEnableOption "stylix config";
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx.common.system.stylix.enable = true;
  };
}
