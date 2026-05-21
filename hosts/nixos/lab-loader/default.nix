# Lab-loader — the shared PXE payload for every lab host.
#
# Builds a kernel + initrd (system.build.netbootRamdisk) that iyr
# serves to lab-1..4. The loader is a perfectly normal NixOS stage-2
# system that happens to live entirely in RAM (via netboot.nix). On
# boot it brings up DHCP, sshd, and runs lab-loader-chain.service
# which fetches its per-host spec and either kexecs into the target
# system or just stays in stage-2 — debuggable like any other host.
#
# Deliberately minimal: appliance role (no users.psyc / home-manager
# / tailscale / etc.). The loader needs root + the operator key + a
# network + an SSH daemon. Everything else is bloat.
{ modulesPath, lib, nixclyx, ... }:
{
  imports = [
    "${modulesPath}/installer/netboot/netboot.nix"
    ./loader.nix
    ./network.nix
  ];

  networking.hostName = "lab-loader";
  # The loader doesn't own a ZFS pool — it just imports whichever
  # the target host created. Stable, non-clashing value.
  networking.hostId = "deadbeef";

  psyclyx.nixos = {
    role = "appliance";

    # All lab hosts are DL360 Gen9: bnx2x + tg3 drivers into initrd,
    # P440ar SCSI driver, intel CPU bits.
    hardware.presets.hpe.dl360-gen9.enable = true;
  };

  # bnx2x and friends — redistributable, gets the 10G NIC online.
  hardware.enableRedistributableFirmware = true;

  # ZFS + NFS in the loader kernel so chain mounts work.
  boot.supportedFilesystems = [ "zfs" "nfs" "nfs4" ];

  # Root's authorized_keys directly: no users.psyc, no home-manager.
  users.users.root.openssh.authorizedKeys.keys = nixclyx.keys.psyc.openssh;

  # Recovery image: no firewall (no zones wired to interfaces because
  # the loader has no egregore entity — default-deny would lock SSH
  # and ICMP out).
  networking.firewall.enable = lib.mkForce false;

  # netboot.nix vs nixclyx defaults clash on an inert bootloader knob.
  boot.loader.timeout = lib.mkForce 10;

  # iLO VSP on DL360 Gen9 = COM2 = ttyS1. Without console=ttyS1 the
  # boot log + getty are video-only.
  boot.kernelParams = [
    "console=tty0"
    "console=ttyS1,115200n8"
  ];
  systemd.services."serial-getty@ttyS1" = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
  };

  # Helpful pointer when fall-through happens.
  environment.etc."issue".text = ''
    lab-loader — stage-2
    --------------------
    If you see this, lab-loader-chain.service either hasn't run yet
    (it's gated on network-online.target) or it bailed without
    kexec'ing. Either way the system is reachable on SSH; check:
      systemctl status lab-loader-chain
      journalctl -u lab-loader-chain --no-pager
      ip -br a
  '';

  system.stateVersion = lib.mkForce "26.05";
}
