{ config, lib, ... }:
let
  cfg = config.psyclyx.services.printing;
in
{
  options = {
    psyclyx = {
      services = {
        printing = {
          enable = lib.mkEnableOption "Enable printing.";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    services = {
      printing = {
        enable = true;
      };
    };
  };
}
