{ inputs, ... }:
let
  inherit (inputs) disko;
in
{
  system.stateVersion = "24.05";
  time.timeZone = "America/Los_Angeles";

  imports = [
    ../../modules/platform/nixos/programs/zsh.nix
    ../../modules/platform/nixos/tailscale.nix
    ../../modules/platform/nixos/base
    ../../modules/platform/nixos/services/soju.nix

    ./boot.nix
    ./filesystems.nix
    ./hardware.nix
    ./network.nix
    ./users.nix
  ];
}
