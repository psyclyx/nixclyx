{ lib, pkgs, ... }:
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

  boot.kernel.sysctl."kernel.sched_autogroup_enabled" = 0;

  # Clevis unlocks tank/persist in initrd by fetching ephemeral key
  # material from iyr's tang server. The .jwe is safe to keep in the
  # repo: without the matching tang key (kept on iyr's /var/lib/tang,
  # never persisted here), it's inert.
  #
  # tank/luns shares the same passphrase but isn't unlocked here —
  # the initrd clevis module asserts a filesystem mounted from each
  # listed dataset, and the luns parent only holds zvols. Unlocked
  # post-boot by the systemd unit below.
  boot.initrd.clevis = {
    enable = true;
    useTang = true;
    devices."tank/persist".secretFile = ./persist.jwe;
  };

  # Post-boot unlock for tank/luns. Same JWE as initrd, materialized
  # from the nix store rather than copied into /etc so it's only
  # readable at unit run-time. Ordered before iSCSI so target setup
  # sees the zvol nodes.
  systemd.services.zfs-load-key-luns = {
    description = "Unseal tank/luns via clevis";
    # iSCSI target binds the luns dataset's zvols, so we only need
    # this to run before it. Don't pull into zfs-import.target /
    # basic.target — that creates a dependency loop via
    # preservation.target's bind mounts on /etc/ssh and breaks
    # SSH host-key persistence on first boot.
    wantedBy = [ "iscsi-target.service" ];
    before = [ "iscsi-target.service" ];
    after = [ "zfs-import-tank.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    path = [ pkgs.clevis pkgs.zfs pkgs.curl pkgs.jose ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "zfs-load-key-luns" ''
        set -euo pipefail
        if [ "$(zfs get -H -o value keystatus tank/luns)" = available ]; then
          exit 0
        fi
        clevis decrypt < ${./persist.jwe} | zfs load-key -L prompt tank/luns
      '';
    };
  };

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
