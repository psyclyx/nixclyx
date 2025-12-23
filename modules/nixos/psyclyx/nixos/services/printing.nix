{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.services.printing;
in
{
  options = {
    psyclyx.nixos.services.printing = {
      enable = mkEnableOption "Enable printing.";
    };
  };

  config = mkIf cfg.enable {
    services.printing = {
      enable = true;
      drivers = [ pkgs.brlaser ];
    };
  };
}
