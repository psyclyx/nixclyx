{ ... }:
{
  nix = {
    settings = {
      trusted-users = [ "@builders" ];
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
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    optimise = {
      automatic = true;
      dates = [ "05:00" ];
    };

    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };
}
