{
  path = ["psyclyx" "nixos" "filesystems" "nfs-root"];
  description = ''
    Diskless host: tmpfs root, NFS /nix + /persist. The actual NFS
    mount entries are derived by the storage projection from the
    host's refs.{nixDataset,persistDataset}; networking (incl. initrd)
    is the network.topology + network.interfaces.initrd job. This
    module only owns the filesystem-layer concerns: tmpfs /, NFS
    modules in initrd, bootloader off.
  '';

  config = { lib, pkgs, ... }: {
    fileSystems."/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=755" ];
    };

    # /nix/store can be shared (immutable, content-addressed); /nix/var
    # cannot. Profiles, gc-roots, the sqlite valid-paths db, and most
    # critically the nix-daemon socket are per-host mutable state. With
    # /nix/var on the NFS-shared dataset, every consumer's nix-daemon
    # binds /nix/var/nix/daemon-socket/socket on the producer's
    # filesystem and overwrites the producer's listening-socket file;
    # the producer's daemon keeps its fd but every new client connect
    # hits a dead socket file and gets ECONNREFUSED. Producer and
    # consumers thrash each other's daemons on every restart.
    #
    # Carve /nix/var out with a tmpfs. Each host gets its own per-boot
    # daemon socket + profile/gc state. Persistent profile generations
    # / rollback history are something PXE-everywhere hosts don't have
    # anyway (no local boot loader), so the tmpfs cost is conceptually
    # consistent with the tmpfs root.
    fileSystems."/nix/var" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=755" ];
      neededForBoot = true;
    };

    # PXE-booted: iyr serves this host's kernel + initialRamdisk
    # directly, no on-disk boot media.
    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.generic-extlinux-compatible.enable = lib.mkForce false;

    # NFS in initrd so neededForBoot mounts from the storage projection
    # can fire before stage-2. The kernel modules let the mount(2)
    # syscall accept the "nfs" fsType; the userspace mount.nfs helper
    # is what resolves "host:/path" into the addr= option the kernel's
    # NFS code requires. Without /sbin/mount.nfs on the initrd PATH,
    # systemd's mount calls hit mount(8)'s direct-syscall fallback and
    # the kernel rejects with `NFS: mount program didn't pass remote
    # address`. extraBin symlinks the binary into /bin and /sbin in
    # the initrd (storePaths alone only ships the store path).
    boot.initrd.kernelModules = [ "nfs" "nfsv4" ];
    boot.initrd.supportedFilesystems = [ "nfs" "nfs4" ];
    boot.initrd.systemd.storePaths = [ pkgs.nfs-utils ];
    boot.initrd.systemd.extraBin = {
      "mount.nfs" = "${pkgs.nfs-utils}/bin/mount.nfs";
      "mount.nfs4" = "${pkgs.nfs-utils}/bin/mount.nfs4";
    };

    # In stage-1, systemd-networkd's built-in /run/systemd/network/
    # 71-default.network catches any interface without a more-specific
    # match — and the storage/lab NICs we don't ship per-device
    # configs for in initrd fall through to it. That fallback's DHCP
    # client-id is DUID-derived from /etc/machine-id; the initrd
    # generates a random machine-id every boot (the real one lives on
    # /persist, which we haven't mounted yet — chicken/egg), so the
    # DUID rotates and Kea can't reuse the per-MAC reservation. The
    # NIC gets a pool IP, which isn't in lab-4's NFS export ACL, and
    # mount.nfs gets "access denied". Override with a higher-priority
    # match that pins client-id to MAC — matching how host.mac.<dev>
    # keys the reservation.
    boot.initrd.systemd.network.networks."70-dhcp-mac" = {
      matchConfig.Name = "en* eth*";
      networkConfig.DHCP = "yes";
      dhcpV4Config = {
        ClientIdentifier = "mac";
        UseDomains = true;
      };
    };

    # The /nix and /persist NFS mount entries themselves are derived
    # by topology/storage.nix from host.refs.{nixDataset,persistDataset}.
    psyclyx.nixos.topology.storage.enable = true;
  };
}
