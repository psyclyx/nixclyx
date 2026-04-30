{
  path = ["psyclyx" "nixos" "filesystems" "layouts" "zfs-pool"];
  description = "ZFS pool disk layout";
  options = {lib, ...}: {
    poolName = lib.mkOption {
      type = lib.types.str;
      default = "rpool";
      description = "ZFS pool name";
    };

    hostId = lib.mkOption {
      type = lib.types.str;
      description = "8-character hex string for networking.hostId";
    };

    boot.UUID = lib.mkOption {
      type = lib.types.str;
      description = "Boot (ESP) partition UUID";
    };

    arc.maxBytes = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      description = "Maximum ARC size in bytes";
    };
  };

  config = {cfg, lib, ...}: let
    pool = cfg.poolName;
  in {
    psyclyx.nixos.filesystems = {
      bcachefs.enable = false;
      zfs = {
        enable = true;
        hostId = cfg.hostId;
        pools = [pool];
        arc.maxBytes = cfg.arc.maxBytes;
      };
    };

    fileSystems = {
      "/" = {
        device = "${pool}/root";
        fsType = "zfs";
        options = ["zfsutil"];
      };
      "/nix" = {
        device = "${pool}/nix";
        fsType = "zfs";
        options = ["zfsutil"];
      };
      "/persist" = {
        device = "${pool}/persist";
        fsType = "zfs";
        options = ["zfsutil"];
      };
      "/var/log" = {
        device = "${pool}/log";
        fsType = "zfs";
        options = ["zfsutil"];
      };
      "/var/lib/postgresql" = {
        device = "${pool}/postgresql";
        fsType = "zfs";
        options = ["zfsutil"];
      };
      "/var/lib/etcd" = {
        device = "${pool}/etcd";
        fsType = "zfs";
        options = ["zfsutil"];
      };
      "/var/lib/redis" = {
        device = "${pool}/redis";
        fsType = "zfs";
        options = ["zfsutil"];
      };
      "/srv/seaweedfs" = {
        device = "${pool}/seaweedfs";
        fsType = "zfs";
        options = ["zfsutil"];
      };
      "/var/lib/containerd/io.containerd.snapshotter.v1.zfs" = {
        device = "${pool}/containerd";
        fsType = "zfs";
        options = ["zfsutil"];
      };
      "/boot" = {
        device = "UUID=${cfg.boot.UUID}";
        fsType = "vfat";
        options = ["umask=0077"];
      };
    };

    # These layouts manage all boot-time ZFS mounts via explicit fileSystems
    # entries. Leaving zfs-mount.service enabled races systemd's generated
    # .mount units when the datasets still have non-legacy mountpoints, which
    # can drop the host into emergency mode on boot.
    systemd.services.zfs-mount.wantedBy = lib.mkForce [];
  };
}
