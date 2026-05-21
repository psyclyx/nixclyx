# Lab-loader — the shared PXE payload for every lab host.
#
# Builds a kernel + initrd (system.build.netbootRamdisk) that iyr
# serves to lab-1..4 (and any future PXE host). The loader is generic:
# it reads `pxe-host` + `pxe-spec-url` from /proc/cmdline, fetches
# the per-host spec JSON, executes its mount steps (ZFS-import,
# clevis-decrypt, ZFS-mount, NFS-mount), then kexecs into the
# target's /persist/var/nix/profiles/system. No system profile →
# drops to SSH-reachable bootstrap mode.
#
# The loader has no egregore entity (it's a fleet *artifact*, not a
# host). That's why this file talks to systemd.network directly in
# network.nix rather than going through network.topology — there's
# no fleet entity to project from. Other knobs use psyclyx.nixos.*
# normally.
{ modulesPath, pkgs, lib, ... }:
{
  imports = [
    "${modulesPath}/installer/netboot/netboot.nix"
    ./loader.nix
    ./bootstrap-mode.nix
    ./network.nix
  ];

  networking.hostName = "lab-loader";
  # Stable hostId: the loader doesn't OWN a pool, just imports one
  # the target host created with its own hostId.
  networking.hostId = "deadbeef";

  psyclyx.nixos = {
    role = "server";

    # All lab hosts are DL360 Gen9: pulls bnx2x + tg3 drivers into
    # initrd, P440ar SCSI driver, intel CPU bits.
    hardware.presets.hpe.dl360-gen9.enable = true;

    # No egregore identity → no zone gets wired for any interface,
    # so the default-deny would silently drop everything. The loader
    # is a stateless recovery image on the physical lab subnet only;
    # firewall off.
    network.firewall.enable = lib.mkForce false;
  };

  # Initrd is where the chain script lives — needs real systemd.
  boot.initrd.systemd.enable = true;
  boot.supportedFilesystems = [ "zfs" "nfs" "nfs4" ];
  boot.initrd.systemd.storePaths = with pkgs; [
    bash coreutils curl jq kexec-tools util-linux
    zfs nfs-utils clevis jose openssh iproute2 iputils cryptsetup
  ];

  # bnx2x firmware is shipped under linux-firmware → redistributable.
  # Without it the 10G LAB NIC fails to come up, the chain can't reach
  # iyr's spec endpoint, and we bail to bootstrap-mode every boot.
  hardware.enableRedistributableFirmware = true;

  # netboot.nix and nixclyx defaults conflict on a few stateful
  # bootloader knobs that are inert for an initrd-only system.
  boot.loader.timeout = lib.mkForce 10;

  # iLO VSP on DL360 Gen9 is wired to COM2 = ttyS1. Without
  # console=ttyS1 the boot log is only on the video console; iLO VSP
  # is blank.
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS1,115200n8"
  ];
  systemd.services."serial-getty@ttyS1" = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
  };

  # Recovery image: autologin root on tty1 + ttyS1. No security risk
  # in this role — no persistent secrets in the loader, and it only
  # appears on the physical lab subnet behind iyr.
  services.getty.autologinUser = "root";
  users.users.root.hashedPasswordFile = lib.mkForce null;
  users.users.root.hashedPassword = lib.mkForce null;
  users.users.root.password = lib.mkForce null;

  environment.etc."issue".text = ''
    lab-loader (stage-2 fall-through — chain did not kexec)
    -------------------------------------------------------
    Autologged as root on console. Useful commands:
      ip a                                  network state
      journalctl -u systemd-networkd        why DHCP isn't running
      journalctl -b | grep -i bnx2x         10G NIC firmware status
      curl http://10.0.210.2:8089/spec/$(
        grep -oE 'pxe-host=[^ ]+' /proc/cmdline | cut -d= -f2
      ).json
  '';
}
