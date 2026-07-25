{ ... }:
{
  # lab-4 PXE-boots its own kernel + initialRamdisk from iyr. Stage-1
  # brings up eno1 via ip=dhcp, clevis-tang unseals the encryptionroots,
  # the pool gets imported, and `/` + /nix + /persist mount from
  # tank/host/lab-4/root + tank/nix-shared + tank/persist/lab-4 (all
  # neededForBoot) before switch_root.
  #
  # Root is a persistent ZFS dataset (tank/host/lab-4/root), declared as a
  # zfs-dataset entity and projected into fileSystems."/" by
  # topology/storage.nix — unlike lab-1..3, which stay stateless
  # netboot with a tmpfs root. No preservation module: state lives on
  # the real root and persists across reboots natively.

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

  # vault holds bulk + archive datasets; the runtime layer's single-
  # pool option only covers tank (the clevis-tang unsealed boot pool).
  # NixOS's extraPools brings vault up post-boot via
  # zfs-import-vault.service.
  boot.zfs.extraPools = [ "vault" ];
}
