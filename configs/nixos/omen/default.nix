{ inputs, pkgs, ... }:
{
  system.stateVersion = "25.05";
  networking.hostName = "omen";
  time.timeZone = "America/Los_Angeles";
  imports = [
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

  stylix = {
    enable = true;
    image = ../../wallpapers/madoka-homura-2x.png;
    opacity = {
      applications = 0.9;
      desktop = 0.8;
      terminal = 0.9;
      popups = 0.8;
    };
    fonts = {
      sizes = {
        desktop = 12;
        applications = 14;
        terminal = 14;
        popups = 14;
      };
      serif = {
        package = pkgs.nerd-fonts.noto;
        name = "NotoSerif Nerd Font";
      };
      sansSerif = {
        package = pkgs.nerd-fonts.noto;
        name = "NotoSans Nerd Font";
      };
      monospace = {
        package = pkgs.aporetic;
        name = "Aporetic Sans Mono";
      };
      emoji = {
        package = pkgs.noto-fonts-emoji;
        name = "Noto Color Emoji";
      };
    };
  };

  psyclyx = {
    programs.sway.enable = true;
    services = {
      autoMount.enable = true;
      gnome-keyring.enable = true;
      greetd.enable = true;
      openssh.enable = true;
      kanata.enable = true;
      printing.enable = true;
      tailscale.enable = true;
    };
    system = {
      fonts.enable = true;
      sudo.enable = true;
    };
  };
}
