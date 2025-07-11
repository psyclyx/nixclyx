{ config, lib, ... }:
let
  cfg = config.psyclyx.services.autoMount;
in
{
  options = {
    psyclyx = {
      services = {
        autoMount = {
          enable = lib.mkEnableOption "Automatically mount disks when connected.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    services = {
      devmon = {
        enable = true;
      };
      udisks2 = {
        enable = true;
      };
    };
  };
}
