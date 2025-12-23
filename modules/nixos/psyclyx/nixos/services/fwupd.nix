{ config, lib, ... }:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.services.fwupd;
in
{
  options = {
    psyclyx.nixos.services.fwupd = {
      enable = mkEnableOption "fwupd";
    };
  };

  config = mkIf cfg.enable {
    services.fwupd.enable = true;
  };
}
