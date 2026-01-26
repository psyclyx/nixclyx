{ nixclyx, ... }:
{ ... }:
{
  imports = [ nixclyx.nixosModules.default ];

  config = {
    networking.hostName = "vigil";

    fileSystems =
      let
        fs = {
          device = "/dev/disk/by-uuid/b45981b5-dd30-416f-89cc-a1eea9a0a9fc";
          fsType = "bcachefs";
        };
      in
      {
        "/" = fs // {
          options = [ "X-mount.subdir=/subvolumes/root" ];
        };

        "/fs" = fs;

        "/nix" = fs // {
          options = [ "X-mount.subdir=/subvolumes/nix" ];
          neededForBoot = true;
        };

        "/persist" = fs // {
          options = [ "X-mount.subdir=/subvolumes/persist" ];
          neededForBoot = true;
        };

        "/var/log" = fs // {
          options = [ "X-mount.subdir=/subvolumes/log" ];
          neededForBoot = true;
        };

        "/boot" = {
          device = "/dev/disk/by-uuid/0289-61AC";
          fsType = "vfat";
          options = [ "umask=0077" ];
        };
      };

    psyclyx = {
      nixos = {
        boot = {
          initrd-ssh.enable = true;
        };

        hardware = {
          cpu.intel.enable = true;
        };

        roles = {
          base.enable = true;
          remote.enable = true;
          utility.enable = true;
        };

        users.psyc = {
          enable = true;
          server = true;
        };
      };
    };
  };
}
