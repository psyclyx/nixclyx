{ inputs, ... }:
{
  system.stateVersion = "25.05";
  networking.hostName = "sigil";
  time.timeZone = "America/Los_Angeles";
  imports = [
    inputs.disko.nixosModules.disko
    inputs.stylix.nixosModules.stylix

    ../../../modules/nixos/nixpkgs.nix
    ../../../modules/nixos/module.nix
    ../../../modules/nixos/system/home-manager.nix

    ./boot.nix
    ./filesystems.nix
    ./hardware.nix
    ./network.nix
    ./users.nix
  ];

  psyclyx = {
    hardware.glasgow = {
      enable = true;
      users = [ "psyc" ];
    };
    programs = {
      aspell.enable = true;
      steam = {
        enable = true;
      };
      sway = {
        enable = true;
      };
    };

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
      home-assistant = {
        enable = true;
      };
      openssh = {
        enable = true;
      };
      locate = {
        enable = true;
        users = [ "psyc" ];
      };
      printing = {
        enable = true;
      };
      tailscale = {
        enable = true;
        exitNode = true;
      };
    };

    system = {
      fonts = {
        enable = true;
      };
      sudo = {
        enable = true;
      };
      virtualization = {
        enable = true;
      };
    };

    stylix = {
      enable = true;
      baseFontSize = 16;
      image = ../../wallpapers/madoka-homura-2x.png;
    };
  };
}
