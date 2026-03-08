{
  config,
  lib,
  ...
}: {
  config = lib.mkIf (config.psyclyx.nixos.host == "glyph") {
    fileSystems = {
      "/" = {
        device = "/dev/disk/by-partlabel/nvme0-root";
        fsType = "bcachefs";
        options = ["X-mount.subdir=subvolumes/root/@live"];
      };

      "/nix" = {
        device = "/dev/disk/by-partlabel/nvme0-root";
        fsType = "bcachefs";
        options = ["X-mount.subdir=subvolumes/nix/@live"];
        neededForBoot = true;
      };

      "/persist" = {
        device = "/dev/disk/by-partlabel/nvme0-root";
        fsType = "bcachefs";
        options = ["X-mount.subdir=subvolumes/persist/@live"];
        neededForBoot = true;
      };

      "/var/log" = {
        device = "/dev/disk/by-partlabel/nvme0-root";
        fsType = "bcachefs";
        options = ["X-mount.subdir=subvolumes/log/@live"];
        neededForBoot = true;
      };

      "/home/psyc" = {
        device = "/dev/disk/by-partlabel/nvme0-root";
        fsType = "bcachefs";
        options = ["X-mount.subdir=subvolumes/home_psyc/@live"];
      };

      "/root" = {
        device = "/dev/disk/by-partlabel/nvme0-root";
        fsType = "bcachefs";
        options = ["X-mount.subdir=subvolumes/home_root/@live"];
      };

      "/boot" = {
        device = "/dev/disk/by-partlabel/nvme0-boot";
        fsType = "vfat";
        options = ["umask=0077"];
      };
    };

    swapDevices = [{device = "/dev/disk/by-partlabel/nvme0-swap";}];
  };
}
