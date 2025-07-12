{ pkgs, ... }:
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
          "adbusers"
          "builders"
        ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwUKqMso49edYpzalH/BFfNlwmLDmcUaT00USWiMoFO me@psyclyx.xyz"
        ];
      };
    };
  };

  home-manager.users.psyc = mkHome {
    name = "psyc";
    email = "me@psyclyx.xyz";
    modules = [
      ../../../modules/home/base
      ../../../modules/home/secrets
      ../../../modules/home/nixos
      ../../../modules/home/xdg.nix
      ../../../modules/home/programs/emacs
      ../../../modules/home/programs/alacritty.nix
      ../../../modules/home/programs/signal.nix
      ../../../modules/home/programs/zsh.nix
      {
        psyclyx = {
          programs = {
            alacritty = {
              enable = true;
            };
            zsh = {
              enable = true;
            };
          };
        };
      }
    ];
  };
}
