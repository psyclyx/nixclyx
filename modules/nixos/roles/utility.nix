{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkDefault mkEnableOption mkIf;

  cfg = config.psyclyx.roles.utility;
in
{
  options = {
    psyclyx.roles.utility = {
      enable = mkEnableOption "role with various system utilities";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      binutils
      dig
      ethtool
      gotop
      htop
      inetutils
      lm_sensors
      magic-wormhole
      p7zip
      pciutils
      pv
      stress-ng
      sysbench
      unzip
      zip
      zstd
    ];

    psyclyx = {
      programs = {
        aspell.enable = mkDefault true;
      };

      services = {
        fwupd.enable = mkDefault true;
        locate.enable = mkDefault true;
      };

      system = {
        sudo.enable = mkDefault true;
      };
    };
  };
}
