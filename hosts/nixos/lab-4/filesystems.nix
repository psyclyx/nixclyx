{...}: let
  uuid = "c9ad48a0-aa58-4734-a7d5-3e6797621405";
  device = "UUID=${uuid}";
  wants = [
    "/dev/disk/by-partlabel/lab4-ssd"
    "/dev/disk/by-partlabel/lab4-hdd"
  ];
  wantsOpts = map (d: "x-systemd.wants=${d}") wants;
in {
  psyclyx.nixos.filesystems.bcachefs.enable = true;

  fileSystems = {
    "/" = {
      inherit device;
      fsType = "bcachefs";
      options = ["X-mount.subdir=subvolumes/root/@live"] ++ wantsOpts;
    };

    "/.fs" = {
      inherit device;
      fsType = "bcachefs";
      options = wantsOpts;
    };

    "/nix" = {
      device = "/.fs/subvolumes/nix/@live";
      fsType = "none";
      options = ["bind"];
      depends = ["/.fs"];
      neededForBoot = true;
    };

    "/persist" = {
      device = "/.fs/subvolumes/persist/@live";
      fsType = "none";
      options = ["bind"];
      depends = ["/.fs"];
      neededForBoot = true;
    };

    "/var/log" = {
      device = "/.fs/subvolumes/log/@live";
      fsType = "none";
      options = ["bind"];
      depends = ["/.fs"];
      neededForBoot = true;
    };

    "/var/lib/postgresql" = {
      device = "/.fs/subvolumes/postgresql/@live";
      fsType = "none";
      options = ["bind"];
      depends = ["/.fs"];
    };

    "/var/lib/redis" = {
      device = "/.fs/subvolumes/redis/@live";
      fsType = "none";
      options = ["bind"];
      depends = ["/.fs"];
    };

    "/srv/seaweedfs" = {
      device = "/.fs/subvolumes/seaweedfs/@live";
      fsType = "none";
      options = ["bind"];
      depends = ["/.fs"];
    };

    "/boot" = {
      device = "UUID=CF86-D5FF";
      fsType = "vfat";
      options = ["umask=0077"];
    };
  };
}
