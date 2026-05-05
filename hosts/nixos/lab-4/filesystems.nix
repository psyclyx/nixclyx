{ ... }:
{
  psyclyx.nixos.filesystems.layouts.zfs-pool = {
    enable = true;
    hostId = "6fa90ede";
    boot.UUID = "CF86-D5FF";
    arc.maxBytes = 137438953472; # 128GB
  };
}
