{nixclyx, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "programs" "steam"];
  description = "Enable steam.";
  config = _: {
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
} args
