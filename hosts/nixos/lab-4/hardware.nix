{ lib, ... }:
{
  psyclyx.nixos = {
    hardware.presets.hpe.dl360-gen9.enable = true;

    # PXE-boot only — no on-disk bootloader. The base role defaults
    # systemd-boot on, which conflicts with the netboot module's
    # tmpfs root + ramdisk-supplied kernel.
    boot.systemd.loader.enable = lib.mkForce false;

    # ZFS in initrd so the encrypted root (tank/root/lab-4) and
    # /persist are available BEFORE switch_root — the OS root itself
    # lives on tank now, so stage-1 must unseal + mount it. Clevis
    # (below) unseals the key against iyr's tang server, so no console
    # interaction is needed in the normal case; if tang is unreachable
    # the upstream zfs initrd falls through to a passphrase prompt at
    # the iLO console.
    filesystems.zfs.encryption.enable = true;

    network = {
      interfaces = {
        # No bond. The 10G NICs (eno49np0/eno50np1) are declared in
        # egregore but parked — we don't yet have a working in-tree
        # driver for them in netboot initrd. The default network is
        # main (eno1, tg3), so initrd brings up the 1G NIC and PXE +
        # tang traffic flows over it. Mellanox/Broadcom 10G modules
        # come from the dl360-gen9 hardware preset for when they're
        # used in stage-2.
        initrd = {
          enable = true;
          kernelModules = [
            "tg3"
          ];
        };
      };

      topology = {
        enable = true;
        defaultNetwork = "main";
      };

      firewall.input.lan.policy = "accept";
    };

    role = "server";
  };

  # LSI SAS 9207-8i (SAS 2308 chipset) carries tank's disks. Without
  # mpt3sas in stage-1, zpool import sees no devices and clevis-tang
  # falls through to the iLO passphrase prompt. Not in the DL360 Gen9
  # preset because the 9207 is an add-in card, not standard kit.
  boot.initrd.availableKernelModules = [ "mpt3sas" ];

  # Remote recovery: sshd in the netboot initrd (port 8022), so a wedged
  # stage-1 (missing closure, unmountable root, tang unreachable) can be
  # fixed over SSH instead of at the iLO. Layer 1 for now — a fresh
  # ephemeral host key each boot; connect with `accept-new`. OpenBao
  # ssh-host-cert signing (layer 2) gets flipped on via
  # `.signing` once the AppRole + clevis JWE are bootstrapped and we can
  # test the cert path on a booting host.
  psyclyx.nixos.boot.initrd-ssh-netboot.enable = true;

  boot.kernel.sysctl."kernel.sched_autogroup_enabled" = 0;

  # Clevis unlock (initrd + post-boot key-load for tank/luns) is
  # projected from the clevis-binding entities in trust-root.nix via
  # topology/storage.nix. The JWE blob lives next door at ./persist.jwe;
  # the binding entities reference it by relative path so it lands in
  # the closure without us having to wire it here.

  # Lab-4's root is a persistent ZFS dataset (tank/host/lab-4/root), so
  # identity continuity — machine-id, SSH host keys, /var/lib/nixos —
  # lives on the real root and survives reboots without preservation.
  # /persist (tank/persist/lab-4) stays mounted for explicit runtime
  # state (e.g. the future scheduler's placement table) but no longer
  # backs the OS identity bits.
}
