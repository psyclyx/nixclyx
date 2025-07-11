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
    ../../modules/platform/nixos/base
    ../../modules/platform/nixos/programs/zsh.nix
    ../../modules/platform/nixos/tailscale.nix
    ./users.nix
    ../../modules/platform/nixos/services/fail2ban.nix
    ./network.nix
    ./hardware.nix
    ./filesystems.nix
    ./nginx.nix
    ./metrics.nix
  ];

  services.openssh.ports = [ 17891 ];
  boot.loader.systemd-boot.enable = true;

}
