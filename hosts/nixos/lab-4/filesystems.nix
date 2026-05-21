{ ... }:
{
  # lab-4 is kexec'd in by the lab-loader once the loader has imported
  # tank, clevis-decrypted tank/persist, and mounted tank/nix-shared
  # at /mnt-nix + tank/persist/lab-4 at /mnt-persist. After kexec the
  # initrd here re-imports the pool (kexec resets ZFS state) and our
  # storage projection wires /nix and /persist from the same datasets.
  #
  # Root is tmpfs (no persistent on-disk OS — only tank holds state).
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=755" ];
  };

  # Bootloader: nothing to manage — the loader kexecs us in.
  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = false;

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
