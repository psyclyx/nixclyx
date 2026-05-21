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

  config = { lib, ... }: {
    fileSystems."/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [ "mode=755" ];
    };

    # Kexec'd in by lab-loader; no bootloader to manage.
    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.generic-extlinux-compatible.enable = lib.mkForce false;

    # NFS in initrd so neededForBoot mounts from the storage projection
    # can fire before stage-2.
    boot.initrd.kernelModules = [ "nfs" "nfsv4" ];
    boot.initrd.supportedFilesystems = [ "nfs" "nfs4" ];

    # The /nix and /persist NFS mount entries themselves are derived
    # by topology/storage.nix from host.refs.{nixDataset,persistDataset}.
    psyclyx.nixos.topology.storage.enable = true;
  };
}
