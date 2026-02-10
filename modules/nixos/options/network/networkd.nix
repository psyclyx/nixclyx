{
  path = ["psyclyx" "nixos" "network" "networkd"];
  description = "systemd-networkd";
  options = {lib, ...}: {
    disableInterfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Interface names to force down (sets ActivationPolicy=down).";
    };
  };
  config = {cfg, lib, ...}: lib.mkMerge [
    {
      networking.useNetworkd = true;
      systemd.network = {
        enable = true;
        wait-online.enable = lib.mkDefault false;
      };
    }
    (lib.mkIf (cfg.disableInterfaces != []) {
      systemd.network.networks."20-disable" = {
        matchConfig.Name = builtins.concatStringsSep " " cfg.disableInterfaces;
        linkConfig.ActivationPolicy = "down";
      };
    })
  ];
}
