{ lib, ... }:
{
  networking.hostName = "lab-3";

  # NFS-rooted from lab-4. The module derives the static-IP kernel
  # cmdline + /nix + /persist mounts from egregore data (lab-3's
  # main-network address, refs.nixDataset, refs.persistDataset).
  psyclyx.nixos.filesystems.nfs-root.enable = true;

  # Recovery convenience: no firewall while we're bringing lab-3
  # online (the default-deny zone has no rules wired for diskless
  # hosts yet). Re-enable once we have a proper zone story.
  networking.firewall.enable = lib.mkForce false;

  services.openssh.enable = true;

  psyclyx.nixos.role = "server";
}
