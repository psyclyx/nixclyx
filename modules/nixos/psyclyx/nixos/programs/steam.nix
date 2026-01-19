{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.nixos.programs.steam;
in
{
  options = {
    psyclyx.nixos.programs.steam = {
      enable = lib.mkEnableOption "Enable steam.";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gamescope.enable = true;
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      extraPackages = [
        pkgs.gamescope
        pkgs.bumblebee
      ];
    };
  };
}
