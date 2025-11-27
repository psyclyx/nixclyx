{ inputs, config, ... }:
{
  imports = [ ./base.nix ];

  config = {
    networking.hostName = "lab-4";

    boot = {
      kernelParams = [ "ip=::::${config.networking.hostName}::dhcp" ];
      initrd = {
        availableKernelModules = [
          "tg3"
          "mlx4_core"
        ];
      };
    };

    fileSystems =
      let
        bcachefsSubvolume = subdir: neededForBoot: {
          device = "/dev/disk/by-label/f0136e-bcachefs";
          fsType = "bcachefs";
          options = [ "X-mount.subdir=${subdir}" ];
          inherit neededForBoot;
        };
      in
      {
        "/" = bcachefsSubvolume "root" false;
        "/nix" = bcachefsSubvolume "nix" false;
        "/persist" = bcachefsSubvolume "persist" true;
        "/var/log" = bcachefsSubvolume "log" true;
        "boot" = {
          device = "/dev/disk/by-partlabel/f0136e-14b2c2-boot";
          fsType = "vfat";
          options = [
            "fmask=0077"
            "dmask=0077"
          ];
        };
      };

    swapDevices = [
      { device = "/dev/disk/by-partlabel/f0136e-05ec41-swap"; }
      { device = "/dev/disk/by-partlabel/f0136e-148d8e-swap"; }
      { device = "/dev/disk/by-partlabel/f0136e-14b2c2-swap"; }
      { device = "/dev/disk/by-partlabel/f0136e-277051-swap"; }
      { device = "/dev/disk/by-partlabel/f0136e-36cdba-swap"; }
      { device = "/dev/disk/by-partlabel/f0136e-5a29cc-swap"; }
    ];
  };

}
