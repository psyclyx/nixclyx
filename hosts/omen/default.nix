{ pkgs, ... }:
{
  system.stateVersion = "24.05";
  networking.hostName = "omen";
  time.timeZone = "America/Los_Angeles";
  imports = [
    ../../modules/nixos/nixpkgs.nix
    ../../modules/nixos/module.nix
    ../../modules/nixos/system/home-manager.nix

    ../../modules/nixos/system/fonts.nix
    ../../modules/nixos/programs/sway.nix

    ./boot.nix
    ./filesystems.nix
    ./hardware.nix
    ./users.nix
  ];

  services.resolved.enable = true;

  psyclyx = {
    services = {
      autoMount = {
        enable = true;
      };
      gnome-keyring = {
        enable = true;
      };
      greetd = {
        enable = true;
      };
      openssh = {
        enable = true;
      };
      printing = {
        enable = true;
      };
      tailscale = {
        enable = true;
      };
    };

    system = {
      sudo = {
        enable = true;
      };
    };
  };
}
