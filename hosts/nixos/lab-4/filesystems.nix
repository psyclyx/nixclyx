{ ... }:
{
  psyclyx.nixos.filesystems.bcachefs.enable = true;

  psyclyx.nixos.filesystems.layouts.bcachefs-subvols = {
    enable = true;
    device = "UUID=c9ad48a0-aa58-4734-a7d5-3e6797621405";
    bootDevice = "UUID=CF86-D5FF";
    extraDeviceWants = [
      "/dev/disk/by-partlabel/lab4-ssd"
      "/dev/disk/by-partlabel/lab4-hdd"
    ];
    baseMount = "/.fs";
    subvolumes = {
      "/" = {
        subdir = "subvolumes/root/@live";
      };
      "/nix" = {
        subdir = "subvolumes/nix/@live";
        neededForBoot = true;
      };
      "/persist" = {
        subdir = "subvolumes/persist/@live";
        neededForBoot = true;
      };
      "/var/log" = {
        subdir = "subvolumes/log/@live";
        neededForBoot = true;
      };
      "/var/lib/postgresql" = {
        subdir = "subvolumes/postgresql/@live";
      };
      "/var/lib/redis" = {
        subdir = "subvolumes/redis/@live";
      };
      "/srv/seaweedfs" = {
        subdir = "subvolumes/seaweedfs/@live";
      };
    };
  };
}
