{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.programs.steam;
in
{
  options = {
    psyclyx.nixos.programs.steam = {
      enable = mkEnableOption "Enable steam.";
    };
  };

  config = mkIf cfg.enable {
    programs.gamescope.enable = true;
    programs.steam = {
      gamescopeSession.enable = true;
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
