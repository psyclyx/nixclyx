{ lib, ... }:
{
  psyclyx.nixos = {
    hardware.presets.hpe.dl360-gen9.enable = true;

    # PXE-boot only — no on-disk bootloader. The base role defaults
    # systemd-boot on, which conflicts with the netboot module's
    # tmpfs root + ramdisk-supplied kernel.
    boot.systemd.loader.enable = lib.mkForce false;

    # ZFS in initrd so /persist (encrypted root tank/persist/lab-4) is
    # available BEFORE stage-2 — preservation needs /persist mounted
    # to bind machine-id, SSH host keys, etc. before systemd and sshd
    # read them. Clevis (below) unseals the key against iyr's tang
    # server, so no console interaction is needed in the normal case;
    # if tang is unreachable the upstream zfs initrd falls through to
    # a passphrase prompt at the iLO console.
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

  boot.kernel.sysctl."kernel.sched_autogroup_enabled" = 0;

  # Clevis unlock (initrd + post-boot key-load for tank/luns) is
  # projected from the clevis-binding entities in trust-root.nix via
  # topology/storage.nix. The JWE blob lives next door at ./persist.jwe;
  # the binding entities reference it by relative path so it lands in
  # the closure without us having to wire it here.

  # Lab-4's root is tmpfs (PXE-booted). /persist (on tank, encrypted)
  # is where identity continuity lives — machine-id stays stable across
  # reboots, SSH host keys persist so known_hosts entries don't churn,
  # and NixOS's own state (e.g. /var/lib/nixos) survives.
  #
  # Note: this is independent of ZFS's hostid (networking.hostId, baked
  # into /etc/hostid at activation). ZFS pool ownership is fine without
  # /persist — preservation is only for the systemd-side identity bits.
  preservation = {
    enable = true;
    preserveAt."/persist" = {
      directories = [
        "/var/lib/nixos"
        "/var/lib/systemd"
        "/var/log/journal"
      ];
      files = [
        { file = "/etc/machine-id"; inInitrd = true; }
        { file = "/etc/ssh/ssh_host_ed25519_key"; mode = "0600"; }
        "/etc/ssh/ssh_host_ed25519_key.pub"
      ];
    };
  };
}
