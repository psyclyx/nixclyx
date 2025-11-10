{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.programs.steam;
in
{
  options = {
    psyclyx = {
      programs = {
        steam = {
          enable = lib.mkEnableOption "Enable steam.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.gamescope.enable = true;
    programs.steam = {
      gamescopeSession.enable = true;
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      extraPackages = with pkgs; [
        gamescope
        bumblebee
      ];
    };
  };
}
