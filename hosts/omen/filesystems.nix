{ ... }:
{
  boot = {
    initrd = {
      luks = {
        devices = {
          "crypted" = {
            device = "/dev/disk/by-uuid/ad19e9a8-82ee-4d6f-a099-288b15bbfce6";
          };
        };
      };
    };
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/2f7b6389-e485-4052-9099-4051ec7e8937";
      fsType = "btrfs";
      options = [ "subvol=@" ];
    };

    "/home" = {
      device = "/dev/disk/by-uuid/2f7b6389-e485-4052-9099-4051ec7e8937";
      fsType = "btrfs";
      options = [ "subvol=@home" ];
    };

    "/nix" = {
      device = "/dev/disk/by-uuid/2f7b6389-e485-4052-9099-4051ec7e8937";
      fsType = "btrfs";
      options = [ "subvol=@nix" ];
    };

    "/persist" = {
      device = "/dev/disk/by-uuid/2f7b6389-e485-4052-9099-4051ec7e8937";
      fsType = "btrfs";
      options = [ "subvol=@persist" ];
    };

    "/var" = {
      device = "/dev/disk/by-uuid/2f7b6389-e485-4052-9099-4051ec7e8937";
      fsType = "btrfs";
      options = [ "subvol=@var" ];
    };

    "/boot" = {
      device = "/dev/disk/by-uuid/0B7A-BCCA";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
  };

  swapDevices = [ { device = "/dev/disk/by-uuid/5613edab-b7a6-40a1-ba7e-777aad805837"; } ];
}
