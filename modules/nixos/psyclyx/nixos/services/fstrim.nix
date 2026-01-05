{ config, lib, ... }:
let
  cfg = config.psyclyx.nixos.services.fstrim;
in
{
  options = {
    psyclyx.nixos.services.fstrim = {
      enable = lib.mkEnableOption "TRIM daemon for SSDs";
    };
  };

  config = lib.mkIf cfg.enable {
    services.fstrim.enable = true;
  };
}
