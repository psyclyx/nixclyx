{
  path = ["psyclyx" "nixos" "programs" "steam"];
  description = "Enable steam.";
  config = {pkgs, ...}: {
    programs.gamescope.enable = true;
    programs.steam = {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
    };
  };
}
