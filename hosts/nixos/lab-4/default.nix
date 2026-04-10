{ lib, ... }: {
  imports = [
    ../lab-shared.nix
    ./filesystems.nix
  ];

  networking.hostName = "lab-4";
}
