{ config, lib, ... }:
let
  cfg = config.psyclyx.services.fstrim;
in
{
  options = {
    psyclyx.services.fstrim = {
      enable = lib.mkEnableOption "TRIM daemon for SSDs";
    };
  };

  config = lib.mkIf cfg.enable {
    services.fstrim.enable = true;
  };
}
