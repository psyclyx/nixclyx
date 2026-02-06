{
  path = ["psyclyx" "nixos" "config" "hosts" "tleilax"];
  variant = ["psyclyx" "nixos" "host"];
  imports = [./network.nix];
  config = {lib, nixclyx, ...}: let
    net = nixclyx.network;
    hub = net.peers.${net.rootHub};
  in {
    networking.hostName = "tleilax";

    fileSystems = {
      "/" = {
        device = "UUID=a5823c8f-07c7-41c5-ad9f-4782cb5ba154";
        fsType = "ext4";
      };
      "/boot" = {
        device = "UUID=C8F3-8E47";
        fsType = "vfat";
        options = ["umask=0077"];
      };
    };

    psyclyx.nixos = {
      hardware.presets.hpe.dl20-gen10.enable = true;

      network = {
        ports.ssh = [17891];

        dns = {
          authoritative.zones = {
            "psyclyx.net" = { peerRecords = true; };
            "psyclyx.xyz" = {
              ttl = 3600;
              extraRecords = ''
                vpn    IN A     ${hub.endpoint}
              '';
            };
          };
          resolver = {
            enable = true;
            interfaces = ["wg0"];
          };
        };
      };

      role = "server";

      services.tailscale.exitNode = true;
    };
  };
}
