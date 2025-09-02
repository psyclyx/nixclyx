{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.roles.utility;
in
{
  options = {
    psyclyx.roles.utility = {
      enable = lib.mkEnableOption "role with various system utilities";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      binutils
      ethtool
      htop
      lm_sensors
      pciutils
    ];
    psyclyx = {
      programs = {
        aspell.enable = lib.mkDefault true;
      };
      services = {
        fwupd.enable = lib.mkDefault true;
        locate = {
          enable = lib.mkDefault true;
        };
      };
      system = {
        sudo.enable = lib.mkDefault true;
      };
    };
  };

}
