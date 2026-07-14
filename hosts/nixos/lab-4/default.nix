{ pkgs, ... }:
{
  imports = [
    ./filesystems.nix
    ./hardware.nix
    ./storage.nix
    ./compute.nix
  ];

  networking.hostName = "lab-4";

  # Recovery aid: this initrd already successfully imports tank and
  # mounts /nix + /persist on every boot (that part has never been the
  # problem). What it lacks is a way to pull in a closure that never
  # made it onto disk. A nix binary in the initrd lets us `nix copy`
  # straight from the iLO console shell, no separate rescue image
  # needed.
  boot.initrd.systemd.extraBin = {
    nix = "${pkgs.nix}/bin/nix";
    nix-store = "${pkgs.nix}/bin/nix-store";
  };
}
