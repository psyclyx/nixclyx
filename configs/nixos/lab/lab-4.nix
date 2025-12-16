{ inputs, config, ... }:
let
  bcachefsDevice = "/dev/disk/by-label/f0136e-bcachefs";
in
{
  imports = [ ./base.nix ];

  config = {
    networking.hostName = "lab-4";

    psyclyx.system.preservation.restore.bcachefs.device = bcachefsDevice;

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
        fs = {
          device = bcachefsDevice;
          fsType = "bcachefs";
        };
        subdir =
          s: neededForBoot:
          fs
          // {
            inherit neededForBoot;
            options = [ "X-mount.subdir=${s}" ];
          };
      in
      {
        "/" = subdir "root" false;
        "/fs" = fs;
        "/nix" = subdir "nix" false;
        "/persist" = subdir "persist" true;
        "/var/log" = subdir "log" true;
        "/boot" = {
          device = "/dev/disk/by-partlabel/f0136e-14b2c2-boot";
          fsType = "vfat";
          options = [ "umask=0077" ];
        };
      };

    swapDevices = [
      {
        device = "/dev/disk/by-partlabel/f0136e-05ec41-swap";
        options = [ "discard" ];
      }
      {
        device = "/dev/disk/by-partlabel/f0136e-148d8e-swap";
        options = [ "discard" ];
      }
      {
        device = "/dev/disk/by-partlabel/f0136e-14b2c2-swap";
        options = [ "discard" ];
      }
      {
        device = "/dev/disk/by-partlabel/f0136e-277051-swap";
        options = [ "discard" ];
      }
      {
        device = "/dev/disk/by-partlabel/f0136e-36cdba-swap";
        options = [ "discard" ];
      }
      {
        device = "/dev/disk/by-partlabel/f0136e-5a29cc-swap";
        options = [ "discard" ];
      }
    ];
  };

}
