{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.nixos.services.printing;
in {
  options = {
    psyclyx.nixos.services.printing = {
      enable = lib.mkEnableOption "Enable printing.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.printing = {
      enable = true;
      drivers = [pkgs.brlaser];
    };
  };
}
