{ inputs, ... }:
{
  system.stateVersion = "24.05";
  time.timeZone = "America/Los_Angeles";
  imports = [
    ../../modules/nixos/services/tailscale.nix
    ../../modules/nixos/services/openssh.nix
    ../../modules/nixos/system/console.nix
    ../../modules/nixos/system/home-manager.nix
    ../../modules/nixos/system/locale.nix
    ../../modules/nixos/system/security.nix
    ../../modules/nixos/system/virtualization.nix

    ../../modules/nixos/services/devmon.nix
    ../../modules/nixos/services/fwupd.nix
    ../../modules/nixos/services/udisks2.nix
    ../../modules/nixos/services/interception-tools.nix

    ../../modules/nixos/services/greetd.nix
    ../../modules/nixos/services/gvfs.nix
    ../../modules/nixos/services/gnome-keyring.nix
    ../../modules/nixos/system/fonts.nix
    ../../modules/nixos/programs/sway.nix

    ../../modules/nixos/services/printing.nix
    ../../modules/nixos/programs/adb.nix
    ../../modules/nixos/programs/nix-ld.nix
    ../../modules/nixos/programs/steam.nix
    ../../modules/nixos/programs/zsh.nix

    ../../modules/nixos/services/home-assistant.nix

    ./boot.nix
    ./filesystems.nix
    ./hardware.nix
    ./network.nix
    ./users.nix
  ];
}
