# Lab-loader — the shared PXE payload for every lab host.
#
# Builds a kernel + initrd (system.build.netbootRamdisk) that iyr
# serves to lab-1..4 (and any future PXE host). The loader is generic:
# reads `pxe-host` + `pxe-spec-url` from /proc/cmdline, fetches the
# per-host spec JSON, executes its mount steps (ZFS-import, clevis-
# decrypt, ZFS-mount, NFS-mount), then kexecs into the target's
# /persist/var/nix/profiles/system. No system profile → drops to
# SSH-reachable bootstrap mode.
#
# Deliberately minimal: no role enabled (roles.server pulls in
# users.psyc → home-manager → ~2 GiB of unrelated dotfiles). The
# loader has no real users, just root with the operator's key.
{ modulesPath, pkgs, lib, nixclyx, ... }:
{
  imports = [
    "${modulesPath}/installer/netboot/netboot.nix"
    ./loader.nix
    ./bootstrap-mode.nix
    ./network.nix
  ];

  networking.hostName = "lab-loader";
  # The loader doesn't own a ZFS pool — it just imports whichever
  # the target host created. Stable, non-clashing value.
  networking.hostId = "deadbeef";

  psyclyx.nixos = {
    # Appliance: minimal nix + networkd + sshd; NO users.psyc /
    # home-manager / tailscale / prometheus / etc.
    role = "appliance";

    # All lab hosts are DL360 Gen9: bnx2x + tg3 drivers into initrd,
    # P440ar SCSI driver, intel CPU bits. Without the firmware (via
    # enableRedistributableFirmware below) the 10G NIC fails and the
    # chain can't reach iyr.
    hardware.presets.hpe.dl360-gen9.enable = true;
  };

  # bnx2x firmware (and friends) — redistributable, gets the 10G NIC
  # actually online.
  hardware.enableRedistributableFirmware = true;

  # Root's authorized_keys directly. No users.psyc / home-manager.
  users.users.root.openssh.authorizedKeys.keys = nixclyx.keys.psyc.openssh;

  # Recovery image semantics: no firewall (default-deny zone has
  # nothing wired to it; would silently drop SSH), autologin on
  # console for emergency debug, no root password.
  networking.firewall.enable = lib.mkForce false;
  services.getty.autologinUser = "root";
  users.users.root.hashedPasswordFile = lib.mkForce null;
  users.users.root.hashedPassword = lib.mkForce null;
  users.users.root.password = lib.mkForce null;

  # Initrd: real systemd so the chain unit and bootstrap-mode unit
  # can sequence and hold against switch-root.
  boot.initrd.systemd.enable = true;
  boot.supportedFilesystems = [ "zfs" "nfs" "nfs4" ];
  boot.initrd.systemd.storePaths = with pkgs; [
    bash coreutils curl jq kexec-tools util-linux
    zfs nfs-utils clevis jose openssh iproute2 iputils cryptsetup
  ];

  # netboot.nix vs nixclyx defaults conflict on a bootloader knob
  # that's inert for an initrd-only system.
  boot.loader.timeout = lib.mkForce 10;

  # iLO VSP on DL360 Gen9 is wired to COM2 = ttyS1. Without
  # console=ttyS1 the boot log is only on the video console.
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS1,115200n8"
  ];
  systemd.services."serial-getty@ttyS1" = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
  };

  environment.etc."issue".text = ''
    lab-loader (stage-2 fall-through — chain did not kexec)
    -------------------------------------------------------
    Autologged as root on console. Useful commands:
      cat /run/lab-loader/chain.log         what the chain script saw
      ip a                                  network state
      journalctl -u systemd-networkd        DHCP / link state
      journalctl -b | grep -i bnx2x         10G NIC firmware status
  '';

  system.stateVersion = lib.mkForce "26.05";
}
