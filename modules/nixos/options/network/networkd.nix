{
  path = ["psyclyx" "nixos" "network" "networkd"];
  description = "systemd-networkd";
  config = {lib, ...}: {
    networking.useNetworkd = true;
    systemd.network = {
      enable = true;
      wait-online.enable = lib.mkDefault false;
    };
  };
}
