{ inputs, pkgs, ... }:
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
          "builders"
        ];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEwUKqMso49edYpzalH/BFfNlwmLDmcUaT00USWiMoFO me@psyclyx.xyz"
        ];
      };
    };
  };

  home-manager = {
    users = {
      psyc = {
        imports = [
          inputs.sops-nix.homeManagerModules.sops
          inputs.self.homeManagerModules.default
          inputs.psyclyx-emacs.homeManagerModules.default
          inputs.stylix.homeModules.stylix
          ../../home/psyc.nix
          ../../home/desktop.nix
        ];
        psyclyx-emacs.enable = true;
        psyclyx = {
          programs = {
            waybar = {
              cores = 4;
            };
          };
        };
      };
    };
  };
}
