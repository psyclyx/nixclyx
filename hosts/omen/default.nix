{ pkgs, ... }:
{
  system.stateVersion = "24.05";
  networking.hostName = "omen";
  time.timeZone = "America/Los_Angeles";
  imports = [
    ../../modules/nixos/nixpkgs.nix
    ../../modules/nixos/module.nix
    ../../modules/nixos/system/home-manager.nix

    ../../modules/nixos/services/devmon.nix
    ../../modules/nixos/services/fwupd.nix
    ../../modules/nixos/services/udisks2.nix
    ../../modules/nixos/services/interception-tools.nix

    ../../modules/nixos/services/greetd.nix
    ../../modules/nixos/services/gvfs.nix
    ../../modules/nixos/services/gnome-keyring.nix
    ../../modules/nixos/system/fonts.nix
    ../../modules/nixos/programs/sway.nix

    ../../modules/nixos/programs/light.nix

    ../../modules/nixos/services/printing.nix
    ../../modules/nixos/programs/adb.nix
    ../../modules/nixos/programs/nix-ld.nix
    ../../modules/nixos/programs/zsh.nix

    ./boot.nix
    ./filesystems.nix
    ./hardware.nix
    ./users.nix
  ];

  services.resolved.enable = true;

  psyclyx = {
    services = {
      openssh.enable = true;
      tailscale.enable = true;
    };

    system = {
      console.enable = true;
    };
  };
}
