{ inputs, ... }:
let
  inherit (inputs) disko;
in
{
  system.stateVersion = "25.05";
  networking.hostName = "ix";
  time.timeZone = "America/Los_Angeles";
  imports = [
    inputs.stylix.nixosModules.stylix
    ../../../modules/nixos/nixpkgs.nix
    ../../../modules/nixos/module.nix
    ../../../modules/nixos/system/home-manager.nix

    ../../../modules/nixos/services/soju.nix

    ./boot.nix
    ./filesystems.nix
    ./hardware.nix
    ./network.nix
    ./users.nix
  ];
  stylix.enable = true;
  stylix.image = ../../wallpapers/madoka-homura-2x.png;

  psyclyx = {
    services = {
      openssh = {
        enable = true;
      };
      tailscale = {
        enable = true;
        exitNode = true;
      };
    };

    system = {
      sudo = {
        enable = true;
      };
    };
  };
}
