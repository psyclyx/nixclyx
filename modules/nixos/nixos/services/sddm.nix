{ config, lib, ... }:
let
  cfg = config.psyclyx.nixos.services.sddm;
in
{
  options = {
    psyclyx.nixos.services.sddm = {
      enable = lib.mkEnableOption "Simple Desktop Display Manager";
    };
  };

  config = lib.mkIf cfg.enable {
    services.displayManager.sddm = {
      enable = true;
      wayland.enable = true;
    };
  };
}
