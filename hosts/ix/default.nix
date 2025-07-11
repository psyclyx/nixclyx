{ inputs, ... }:
let
  inherit (inputs) disko;
in
{
  system.stateVersion = "24.05";
  time.timeZone = "America/Los_Angeles";

  imports = [
    ../../modules/nixos/programs/nix-ld.nix
    ../../modules/nixos/programs/zsh.nix
    ../../modules/nixos/services/tailscale.nix
    ../../modules/nixos/services/openssh.nix
    ../../modules/nixos/system/console.nix
    ../../modules/nixos/system/home-manager.nix
    ../../modules/nixos/system/locale.nix
    ../../modules/nixos/system/security.nix
    ../../modules/nixos/services/soju.nix

    ./boot.nix
    ./filesystems.nix
    ./hardware.nix
    ./network.nix
    ./users.nix
  ];
}
