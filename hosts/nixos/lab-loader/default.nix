# Lab-loader — the shared PXE payload for every lab host.
#
# Builds a kernel + initrd combo (system.build.netbootRamdisk) that
# the PXE projection serves to lab-1..4 (and any future host with
# boot.mode = "pxe"). The loader is generic: it knows nothing about
# specific hosts. At boot it reads `pxe-host` + `pxe-spec-url` from
# the kernel cmdline, fetches a per-host spec JSON from iyr's
# pxe-server, executes the spec's mount steps (ZFS-import, clevis-
# decrypt, ZFS-mount, NFS-mount), then kexecs into the target's
# /persist/var/nix/profiles/system. No system profile → drops to
# SSH-reachable bootstrap mode.
#
# Architectural payoff: when lab-4's hypervisor closure rebuilds,
# only that closure needs to land on lab-4 — iyr's PXE serves the
# same lab-loader artifact it served yesterday.
{ modulesPath, pkgs, lib, ... }:
{
  imports = [
    "${modulesPath}/installer/netboot/netboot.nix"
    ./loader.nix
    ./bootstrap-mode.nix
    ./network.nix
  ];

  # netboot.nix and modules.common collide on a few stateful knobs.
  # The loader is initrd-only and never reaches the bootloader stage,
  # so the actual values are inert; mkForce just picks one to silence
  # the merge conflicts.
  boot.loader.timeout = lib.mkForce 10;

  # The loader is initrd-only — it lives in stage-1 until it kexecs
  # away. boot.initrd.systemd is essential: we want real units,
  # ordering, sshd-in-bootstrap-mode, and proper logging in initrd.
  boot.initrd.systemd.enable = true;

  # ZFS + NFS need to be actually built against the loader's kernel,
  # not just listed as kernel modules.
  boot.supportedFilesystems = [ "zfs" "nfs" "nfs4" ];

  # Modules the spec interpreter may need available at stage-1.
  boot.initrd.availableKernelModules = [
    "nfs" "nfsv4"
  ];

  # Tools the loader script invokes. boot.initrd.systemd.storePaths
  # is what makes these end up baked into the initrd squashfs.
  boot.initrd.systemd.storePaths = with pkgs; [
    bash
    coreutils
    curl
    jq
    kexec-tools
    util-linux           # mount, umount
    zfs
    nfs-utils
    clevis
    jose
    openssh
    iproute2
    iputils              # ping (debug)
    cryptsetup           # clevis luks (if/when we use luks)
  ];

  # ZFS needs hostId set in initrd (any 8-hex is fine — the loader
  # is reading pools created elsewhere, not creating any). Pinned so
  # the value doesn't churn across rebuilds.
  networking.hostId = "deadbeef";

  networking.hostName = "lab-loader";

  # Minimal role; the loader has no real users / display / desktop.
  psyclyx.nixos.role = "server";

  # Stage-2 sshd — reachable in the fall-through path when the chain
  # script bailed without kexec'ing. PermitRootLogin via the same
  # operator key the bootstrap-mode initrd unit uses.
  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = lib.mkForce "prohibit-password";

  # Tag the box obviously in stage-2 too.
  environment.etc."issue".text = ''
    lab-loader (stage-2 fall-through — chain did not kexec)
    -------------------------------------------------------
    Autologged as root on tty1. Useful commands:
      ip a                                  network state
      journalctl -u systemd-networkd        why DHCP isn't running
      journalctl -u lab-loader-chain        why the chain bailed
      curl http://10.0.210.2:8089/spec/$(cat /proc/cmdline | grep -oE 'pxe-host=[^ ]+' | cut -d= -f2).json
  '';

  # Recovery image: autologin root on console so the operator can
  # actually do something without SSH. Not a security risk in this
  # specific role — the loader has no persistent secrets and is only
  # ever reached on the physical lab subnet.
  services.getty.autologinUser = "root";

  # No password set for root, but autologin bypasses that. Make sure
  # NixOS won't refuse to construct an unprotected root account.
  users.users.root.hashedPasswordFile = lib.mkForce null;
  users.users.root.hashedPassword = lib.mkForce null;
  users.users.root.password = lib.mkForce null;
}
