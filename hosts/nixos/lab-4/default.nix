{ ... }:
{
  imports = [
    ./filesystems.nix
    ./hardware.nix
    ./storage.nix
  ];

  networking.hostName = "lab-4";
}
