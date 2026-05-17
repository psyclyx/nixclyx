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
    # read them. Passphrase prompts at the iLO console (initrd-ssh
    # would need a sops-managed initrd host key baked at build time,
    # which we'll wire up alongside tang/clevis later).
    filesystems.zfs.encryption.enable = true;

    network = {
      interfaces = {
        # No bond. Lab-4 speaks only over its two 10G NICs. The initrd
        # for netboot has its networking set up by nixpkgs' netboot
        # module; this list ensures the right SFP+ NIC drivers come
        # along for the ride.
        initrd = {
          enable = true;
          kernelModules = [
            "i40e"
            "ixgbe"
            "tg3"
          ];
        };
      };

      topology = {
        enable = true;
        # Default route via the lab VLAN — CRS326 hardware-routes to
        # everywhere else. Storage stays on its own policy table.
        defaultNetwork = "lab";
      };

      firewall.input.lan.policy = "accept";
    };

    role = "server";
  };

  boot.kernel.sysctl."kernel.sched_autogroup_enabled" = 0;

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
