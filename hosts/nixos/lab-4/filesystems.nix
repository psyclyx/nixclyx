{ modulesPath, ... }:
{
  imports = [
    # Netboot client machinery: tmpfs root, kernel + initrd built into a
    # netbootRamdisk that the PXE server serves. lab-4 has no persistent
    # rootfs on disk — the OS comes from PXE every boot. Local SSDs only
    # carry the tank pool (declared via zfs-pool entities) for runtime
    # state and VM disks.
    "${modulesPath}/installer/netboot/netboot.nix"
  ];

  # disko config + zfs-runtime per-dataset mounts are derived by
  # topology/storage.nix from the zfs-pool / zfs-dataset entities in
  # configs/egregore/storage.nix. Only the runtime knobs (pool name,
  # hostId, ARC cap) live here.
  psyclyx.nixos.filesystems.zfs-runtime = {
    enable = true;
    poolName = "tank";
    hostId = "6fa90ede";
    arc.maxBytes = 137438953472; # 128 GiB
  };
}
