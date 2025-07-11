{ pkgs, ... }:
{
  system.stateVersion = "24.05";
  time.timeZone = "America/Los_Angeles";
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/physical
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
