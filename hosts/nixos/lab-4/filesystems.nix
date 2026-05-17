{ modulesPath, ... }:
{
  imports = [
    # Netboot client machinery: tmpfs root, kernel + initrd built into a
    # netbootRamdisk that the PXE server serves. lab-4 has no persistent
    # rootfs on disk — the OS comes from PXE every boot. Local SSDs only
    # carry the tank pool (declared via disko below) for runtime state
    # and VM disks.
    "${modulesPath}/installer/netboot/netboot.nix"
  ];

  # --- Pool layout (used by nixos-anywhere on first install) -----------
  #
  # 8 × 800 GB SSDs as 4 mirrored vdevs (~3.2 TiB usable). Disk by-id
  # paths must be filled in before running nixos-anywhere; the names
  # used here (SSD0..SSD7) are placeholders the operator replaces with
  # the real device IDs from `ls -la /dev/disk/by-id/`.
  disko.devices = {
    disk =
      let
        mkDisk = id: {
          type = "disk";
          device = "/dev/disk/by-id/${id}";
          content = {
            type = "gpt";
            partitions.zfs = {
              size = "100%";
              content = {
                type = "zfs";
                pool = "tank";
              };
            };
          };
        };
      in
      {
        ssd0 = mkDisk "PLACEHOLDER-SSD0";
        ssd1 = mkDisk "PLACEHOLDER-SSD1";
        ssd2 = mkDisk "PLACEHOLDER-SSD2";
        ssd3 = mkDisk "PLACEHOLDER-SSD3";
        ssd4 = mkDisk "PLACEHOLDER-SSD4";
        ssd5 = mkDisk "PLACEHOLDER-SSD5";
        ssd6 = mkDisk "PLACEHOLDER-SSD6";
        ssd7 = mkDisk "PLACEHOLDER-SSD7";
      };

    zpool.tank = {
      type = "zpool";
      mode = {
        topology.type = "topology";
        topology.vdev = [
          { mode = "mirror"; members = [ "ssd0" "ssd1" ]; }
          { mode = "mirror"; members = [ "ssd2" "ssd3" ]; }
          { mode = "mirror"; members = [ "ssd4" "ssd5" ]; }
          { mode = "mirror"; members = [ "ssd6" "ssd7" ]; }
        ];
      };

      rootFsOptions = {
        canmount = "off";
        mountpoint = "none";
        compression = "zstd";
        atime = "off";
        xattr = "sa";
        acltype = "posixacl";
      };

      datasets = {
        # Plaintext datasets — NFS-shared closure (reproducible, no
        # secrets) and ephemeral scratch.
        nix-shared = {
          type = "zfs_fs";
          mountpoint = "/srv/nfs/nix";
          options.mountpoint = "legacy";
        };
        scratch = {
          type = "zfs_fs";
          options.mountpoint = "none";
        };

        # Encrypted parent — children inherit. Holds per-host /persist
        # subdirs (lab-4 mounts its own subdir at /persist; the others
        # are NFS-exported to lab-1..3).
        persist = {
          type = "zfs_fs";
          options = {
            encryption = "aes-256-gcm";
            keyformat = "passphrase";
            keylocation = "prompt";
            mountpoint = "none";
          };
        };
        "persist/lab-4" = {
          type = "zfs_fs";
          mountpoint = "/persist";
          options.mountpoint = "legacy";
        };
        "persist/lab-1" = {
          type = "zfs_fs";
          mountpoint = "/srv/nfs/persist/lab-1";
          options.mountpoint = "legacy";
        };
        "persist/lab-2" = {
          type = "zfs_fs";
          mountpoint = "/srv/nfs/persist/lab-2";
          options.mountpoint = "legacy";
        };
        "persist/lab-3" = {
          type = "zfs_fs";
          mountpoint = "/srv/nfs/persist/lab-3";
          options.mountpoint = "legacy";
        };

        # Encrypted parent for zvols — VM disks live as zvols under here.
        luns = {
          type = "zfs_fs";
          options = {
            encryption = "aes-256-gcm";
            keyformat = "passphrase";
            keylocation = "prompt";
            mountpoint = "none";
            canmount = "off";
          };
        };
      };
    };
  };

  # --- Runtime mounts (declared via the runtime wrapper) ---------------
  psyclyx.nixos.filesystems.zfs-runtime = {
    enable = true;
    poolName = "tank";
    hostId = "6fa90ede";
    arc.maxBytes = 137438953472; # 128 GiB

    datasets = {
      "tank/persist/lab-4" = {
        mountpoint = "/persist";
        options = [ "zfsutil" ];
        # NOT neededForBoot — pre-disko, the tank pool doesn't exist
        # yet, and stage-1 would hang waiting. Best-effort: if the
        # pool's there we mount; if not, boot proceeds without /persist
        # (SSH host keys regenerated each boot until disko runs).
        neededForBoot = false;
      };
      "tank/nix-shared" = {
        mountpoint = "/srv/nfs/nix";
        options = [ "zfsutil" ];
      };
      "tank/persist/lab-1" = {
        mountpoint = "/srv/nfs/persist/lab-1";
        options = [ "zfsutil" ];
      };
      "tank/persist/lab-2" = {
        mountpoint = "/srv/nfs/persist/lab-2";
        options = [ "zfsutil" ];
      };
      "tank/persist/lab-3" = {
        mountpoint = "/srv/nfs/persist/lab-3";
        options = [ "zfsutil" ];
      };
    };
  };
}
