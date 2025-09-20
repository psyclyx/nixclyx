{ inputs, pkgs, ... }:
{
  nix.settings.trusted-users = [ "psyc" ];
  users = {
    users = {
      psyc = {
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "video"
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
    imports = [ ../../home/psyc.nix ];
    psyclyx.configs.psyc = {
      enable = true;
      secrets = true;
    };
  };
}
