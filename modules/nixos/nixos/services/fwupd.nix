{ config, lib, ... }:
let
  cfg = config.psyclyx.nixos.services.fwupd;
in
{
  options = {
    psyclyx.nixos.services.fwupd = {
      enable = lib.mkEnableOption "fwupd";
    };
  };

  config = lib.mkIf cfg.enable {
    services.fwupd.enable = true;
  };
}
