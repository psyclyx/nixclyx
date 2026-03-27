{ lib, ... }: {
  imports = [ ../lab-shared.nix ];

  networking.hostName = "lab-3";
  psyclyx.nixos.filesystems.layouts.zfs-pool = {
    enable = true;
    hostId = "e5955fc5";
    boot.UUID = "C9AE-DE06";
    arc.maxBytes = 42949672960; # 40GB
  };
}
