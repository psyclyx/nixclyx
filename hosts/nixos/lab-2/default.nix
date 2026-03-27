{ lib, ... }: {
  imports = [ ../lab-shared.nix ];

  networking.hostName = "lab-2";
  psyclyx.nixos.filesystems.layouts.zfs-pool = {
    enable = true;
    hostId = "9f6057a5";
    boot.UUID = "BDD2-F0BF";
    arc.maxBytes = 34359738368; # 32GB
  };
}
