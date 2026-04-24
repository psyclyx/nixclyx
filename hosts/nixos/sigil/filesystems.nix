{ ... }:
{
  psyclyx.nixos.filesystems.bcachefs.enable = true;

  psyclyx.nixos.filesystems.layouts.bcachefs-subvols = {
    enable = true;
    device = "UUID=055d9737-c13b-4262-abe6-2ebcb8681307";
    bootDevice = "UUID=71AE-12DD";
    extraDeviceWants = [
      "/dev/disk/by-id/ata-WDC_WDS500G2B0A-00SM50_194894802985"
      "/dev/disk/by-id/ata-ST4000NM0035-1V4107_ZC12M6AQ"
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
      "/home/psyc" = {
        subdir = "subvolumes/home_psyc/@live";
      };
      "/root" = {
        subdir = "subvolumes/home_root/@live";
      };
    };
  };
}
