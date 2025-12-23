{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.services.fstrim;
in
{
  options = {
    psyclyx.nixos.services.fstrim = {
      enable = mkEnableOption "TRIM daemon for SSDs";
    };
  };

  config = mkIf cfg.enable {
    services.fstrim.enable = true;
  };
}
