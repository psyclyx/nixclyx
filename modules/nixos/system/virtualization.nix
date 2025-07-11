{ config, lib, ... }:
let
  cfg = config.psyclyx.system.virtualization;
in
{
  options = {
    psyclyx = {
      system = {
        virtualization = {
          enable = lib.mkEnableOption "Enable virtualization.";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    # NixOS option uses british spelling
    virtualisation = {
      docker = {
        enable = true;
      };
    };
  };
}
