{ pkgs, ... }:
{
  system.stateVersion = "24.05";
  time.timeZone = "America/Los_Angeles";
  imports = [
    ../../modules/platform/nixos/base
    ../../modules/platform/nixos/physical
    ../../modules/platform/nixos/graphical
    ../../modules/platform/nixos/laptop
    ../../modules/platform/nixos/services/printing.nix
    ../../modules/platform/nixos/programs/adb.nix
    ../../modules/platform/nixos/programs/zsh.nix

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
