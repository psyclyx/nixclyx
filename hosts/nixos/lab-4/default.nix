{ ... }:
{
  imports = [
    ./filesystems.nix
    ./hardware.nix
    ./storage.nix
    ./compute.nix
  ];

  networking.hostName = "lab-4";
}
