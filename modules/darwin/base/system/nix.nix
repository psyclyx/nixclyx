{ ... }:
{
  nix = {
    settings = {
      trusted-users = [ "@staff" ];

      substituters = [
        "https://nix-community.cachix.org"
        "https://psyclyx.cachix.org"
      ];

      trusted-public-keys = [
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "psyclyx.cachix.org-1:UFwKXEDn3gLxIW9CeXGdFFUzCIjj8m6IdAQ7GA4XfCk="
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
}
