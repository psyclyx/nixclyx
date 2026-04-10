{ config, lib, ... }: {
  imports = [./filesystems.nix ./network.nix];

  networking.hostName = "semuta";

  # Hetzner Cloud VPS (QEMU/KVM virtio)
  boot.initrd.availableKernelModules = [
    "virtio_pci" "virtio_blk" "virtio_scsi" "virtio_net"
    "virtio_ring" "virtio"
    "ahci" "sd_mod" "sr_mod"
  ];

  psyclyx.nixos = {
    network = {
      firewall = {
        enable = true;
        zones = {
          wg.interfaces = ["wg0"];
          public.interfaces = ["en*" "eth*"];
        };
        input = {
          wg.policy = "accept";
          public = {
            policy = "drop";
            allowICMP = true;
            allowedTCPPorts = with config.psyclyx.nixos.network.ports; ssh.tcp;
            allowedUDPPorts = with config.psyclyx.nixos.network.ports; wireguard.udp;
          };
        };
        forward = [
          {from = "wg"; to = "wg";}
          {from = "wg"; to = "public";}
        ];
        masquerade = [
          {from = "wg"; to = "public";}
        ];
      };
    };

    role = "server";

    # No encryption on this VPS
    filesystems.bcachefs.enable = false;
  };
}
