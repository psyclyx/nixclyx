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

  # disko config, per-dataset mounts, and the pool-import classification
  # are all derived by derived/storage.nix from the zfs-pool / zfs-dataset
  # entities in configs/egregore/storage.nix. Pool names come from those
  # entities; only the knobs that aren't fleet data live here.
  #
  # That derivation is what distinguishes tank from vault without either
  # being named: tank carries neededForBoot datasets (/, /nix, /persist) so
  # initrd imports it, while vault has none and is brought up post-boot via
  # zfs-import-vault.service.
  psyclyx.nixos.filesystems.zfs = {
    enable = true;
    hostId = "6fa90ede";
    arc.maxBytes = 137438953472; # 128 GiB
  };
}
