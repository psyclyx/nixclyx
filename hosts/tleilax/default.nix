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
  time.timeZone = "America/Los_Angeles";
  imports = [
    ../../modules/nixos/base
    ../../modules/nixos/programs/zsh.nix
    ../../modules/nixos/tailscale.nix
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
