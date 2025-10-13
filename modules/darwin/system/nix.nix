{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.system.nix;
in
{
  options = {
    psyclyx.system.nix = {
      enable = lib.mkEnableOption "Nix config";
    };
  };

  config = lib.mkIf cfg.enable {
    nix = {
      package = pkgs.lix;

      settings = {
        trusted-users = [ "@staff" ];

        substituters = [
          "https://psyclyx.cachix.org?priority=0"
          "https://nix-community.cachix.org?priority=1"
        ];

        trusted-public-keys = [
          "psyclyx.cachix.org-1:UFwKXEDn3gLxIW9CeXGdFFUzCIjj8m6IdAQ7GA4XfCk="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };

      gc = {
        automatic = true;
        interval.Day = 7;
        options = "--delete-older-than 7d";
      };

      optimise = {
        automatic = true;
        interval.Day = 7;
      };

      extraOptions = ''
        experimental-features = nix-command flakes
      '';
    };
  };
}
