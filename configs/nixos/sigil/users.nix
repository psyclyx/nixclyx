{ pkgs, lib, ... }:
let
  mkHome = import ../../../modules/home;
in
{
  nix.settings.trusted-users = [ "psyc" ];
  users = {
    users = {
      psyc = {
        name = "psyc";
        home = "/home/psyc";
        shell = pkgs.zsh;
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "video"
          "networkmanager"
          "builders"
          "docker"
        ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwUKqMso49edYpzalH/BFfNlwmLDmcUaT00USWiMoFO me@psyclyx.xyz"
        ];
      };
    };
  };
  home-manager.users.psyc = {
    imports = [
      ../../../modules/home/module.nix
      ../../../modules/home/secrets
      ../../../modules/home/nixos
      ../../../modules/home/programs/emacs
    ];
    home = {
      stateVersion = "25.05";
      packages = with pkgs; [
        firefox-bin
        signal-desktop-bin
      ];
    };
    psyclyx = {
      programs = {
        alacritty = {
          enable = true;
        };
        git = {
          enable = true;
        };
        ssh = {
          enable = true;
        };
        sway = {
          enable = true;
        };
        waybar = {
          enable = true;
          cores = 32;
        };
        zsh = {
          enable = true;
        };
      };
      user = {
        name = "psyclyx";
        email = "me@psyclyx.xyz";
      };
      xdg = {
        enable = true;
      };
    };
  };
}
