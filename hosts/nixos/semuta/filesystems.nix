{ ... }:
{
  psyclyx.nixos.filesystems.layouts.bcachefs-subvols = {
    enable = true;
    device = "PARTLABEL=sda-root";
    bootDevice = "PARTLABEL=sda-boot";
    baseMount = "/.fs";
    subvolumes = {
      "/" = {
        subdir = "subvolumes/root";
      };
      "/nix" = {
        subdir = "subvolumes/nix";
        neededForBoot = true;
      };
      "/var/log" = {
        subdir = "subvolumes/log";
        neededForBoot = true;
      };
      "/home/psyc" = {
        subdir = "subvolumes/home_psyc";
      };
      "/root" = {
        subdir = "subvolumes/home_root";
      };
    };
  };
}
