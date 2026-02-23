{
  path = ["psyclyx" "nixos" "network" "networkd"];
  description = "systemd-networkd";
  config = {
    cfg,
    lib,
    ...
  }: {
    networking.useNetworkd = true;
    systemd.network = {
      enable = true;
    };
  };
}
