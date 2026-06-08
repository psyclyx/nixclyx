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

    # The /nix and /persist NFS mount entries themselves are derived
    # by topology/storage.nix from host.refs.{nixDataset,persistDataset}.
    psyclyx.nixos.topology.storage.enable = true;
  };
}
