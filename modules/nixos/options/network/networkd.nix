{nixclyx, lib, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "nixos" "network" "networkd"];
  description = "systemd-networkd";
  config = _: {
    networking.useNetworkd = true;
    systemd.network = {
      enable = true;
      wait-online.enable = lib.mkDefault false;
    };
  };
} args
