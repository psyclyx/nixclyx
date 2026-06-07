{ ... }:
{
  # lab-4 PXE-boots its own kernel + initialRamdisk from iyr. Stage-1
  # brings up eno1 via ip=dhcp, clevis-tang unseals tank/persist, the
  # pool gets imported, and /nix + /persist mount from
  # tank/nix-shared + tank/persist/lab-4 (both neededForBoot). No
  # kexec, no lab-loader bounce.
  #
  # Root is tmpfs (no persistent on-disk OS — only tank holds state).
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [ "mode=755" ];
  };

  # Bootloader: nothing to manage — iyr serves the kernel/initrd.
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
