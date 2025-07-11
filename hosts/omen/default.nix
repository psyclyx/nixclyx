{ pkgs, ... }:
{
  system.stateVersion = "24.05";
  time.timeZone = "America/Los_Angeles";
  imports = [
    ../../modules/nixos/services/openssh.nix
    ../../modules/nixos/system/console.nix
    ../../modules/nixos/system/home-manager.nix
    ../../modules/nixos/system/locale.nix
    ../../modules/nixos/system/security.nix

    ../../modules/nixos/services/devmon.nix
    ../../modules/nixos/services/fwupd.nix
    ../../modules/nixos/services/udisks2.nix
    ../../modules/nixos/services/interception-tools.nix

    ../../modules/nixos/graphical
    ../../modules/nixos/laptop
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
  networking.useDHCP = true;
  networking.interfaces.tailscale0.useDHCP = false;
  services.tailscale = {
    enable = true;
  };
  networking.firewall.allowedUDPPorts = [ 41641 ];
  environment.systemPackages = [ pkgs.tailscale ];
}
