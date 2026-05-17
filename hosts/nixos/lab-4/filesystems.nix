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

  # --- Pool layout (used by disko on first install) --------------------
  #
  # 8 × 800 GB SSDs as a single RAIDZ2 vdev (~4.8 TiB usable, any
  # 2 disks can fail). Random-IO penalty vs 4× mirror is small on SSDs
  # and the capacity gain is worth it at current SSD prices.
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
        ssd0 = mkDisk "wwn-0x55cd2e404c258d01"; # sda LK0800GEYMU
        ssd1 = mkDisk "wwn-0x55cd2e404c3a6735"; # sdb LK0800GEYMU
        ssd2 = mkDisk "wwn-0x55cd2e404c157a56"; # sdc INTEL SSDSC2BX800G4
        ssd3 = mkDisk "wwn-0x55cd2e404c2594de"; # sdd LK0800GEYMU
        ssd4 = mkDisk "wwn-0x55cd2e404c25f5ea"; # sde LK0800GEYMU
        ssd5 = mkDisk "wwn-0x5000cca04fb8e258"; # sdf HUSMM1680ASS204
        ssd6 = mkDisk "wwn-0x5000cca02b04a3ec"; # sdg MO0800JDVEV
        ssd7 = mkDisk "wwn-0x5000cca02b11aab0"; # sdh MO0800JDVEV
      };

    zpool.tank = {
      type = "zpool";
      mode = {
        topology.type = "topology";
        topology.vdev = [
          {
            mode = "raidz2";
            members = [ "ssd0" "ssd1" "ssd2" "ssd3" "ssd4" "ssd5" "ssd6" "ssd7" ];
          }
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
        # Stage-1 needs /persist available so preservation can bind
        # /etc/machine-id, /etc/ssh/ssh_host_*, etc. before systemd
        # and sshd read them. Tank is imported in initrd; the operator
        # types the encryption-root passphrase at iLO console (until
        # tang/clevis lands).
        neededForBoot = true;
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
