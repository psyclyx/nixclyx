{
  inputs,
  modulesPath,
  pkgs,
  ...
}:
let
in
{
  system.stateVersion = "24.05";
  networking.hostName = "tleilax";
  time.timeZone = "America/Los_Angeles";
  imports = [
    ../../modules/nixos/services/openssh.nix
    ../../modules/nixos/system/console.nix
    ../../modules/nixos/system/home-manager.nix
    ../../modules/nixos/system/locale.nix
    ../../modules/nixos/system/security.nix
    ../../modules/nixos/programs/zsh.nix
    ../../modules/nixos/programs/nix-ld.nix
    ../../modules/nixos/services/tailscale.nix
    ../../modules/nixos/services/fail2ban.nix

    ./users.nix
    ./network.nix
    ./hardware.nix
    ./filesystems.nix
    ./nginx.nix
    ./metrics.nix
  ];
  services.openssh.ports = [ 17891 ];
  boot.loader.systemd-boot.enable = true;
}
