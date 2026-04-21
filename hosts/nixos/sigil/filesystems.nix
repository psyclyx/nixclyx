{...}: let
  fsUUID = "055d9737-c13b-4262-abe6-2ebcb8681307";
  bootUUID = "71AE-12DD";
  device = "UUID=${fsUUID}";

  wants = [
    "/dev/disk/by-id/ata-WDC_WDS500G2B0A-00SM50_194894802985"
    "/dev/disk/by-id/ata-ST4000NM0035-1V4107_ZC12M6AQ"
  ];

  wantOpts = map (d: "x-systemd.wants=${d}") wants;

  bindMount = subdir: {
    device = "/.fs/subvolumes/${subdir}/@live";
    fsType = "none";
    options = ["bind"];
  };
in {
  psyclyx.nixos.filesystems.bcachefs.enable = true;

  fileSystems = {
    "/" = {
      inherit device;
      fsType = "bcachefs";
      options = wantOpts ++ ["X-mount.subdir=subvolumes/root/@live"];
      neededForBoot = true;
    };

    "/.fs" = {
      inherit device;
      fsType = "bcachefs";
      options = wantOpts;
      neededForBoot = true;
    };

    "/nix" = bindMount "nix" // { neededForBoot = true; };
    "/persist" = bindMount "persist" // { neededForBoot = true; };
    "/var/log" = bindMount "log" // { neededForBoot = true; };
    "/home/psyc" = bindMount "home_psyc";
    "/root" = bindMount "home_root";

    "/boot" = {
      device = "UUID=${bootUUID}";
      fsType = "vfat";
      options = ["umask=0077"];
    };
  };
}
