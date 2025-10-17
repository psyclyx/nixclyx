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
      dig
      ethtool
      gotop
      htop
      inetutils
      lm_sensors
      pciutils
      unzip
      zip
      zstd
      magic-wormhole
      pv
      stress-ng
      sysbench
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
