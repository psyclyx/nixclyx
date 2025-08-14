{ inputs, pkgs, ... }:
let
  substituters = [
    "https://psyclyx.cachix.org?priority=0"
    "https://nix-community.cachix.org?priority=1"
    "https://chaotic-nyx.cachix.org?priority=2"
  ];
  trusted-substituters = substituters ++ [
    "https://nixos-raspberrypi.cachix.org?priority=3"
  ];
in
{
  nix = {
    package = pkgs.lix;
    registry.nixpkgs.flake = inputs.nixpkgs;
    settings = {
      inherit substituters trusted-substituters;
      http-connections = 128;
      connect-timeout = 5;
      trusted-users = [ "@builders" ];
      trusted-public-keys = [
        "psyclyx.cachix.org-1:UFwKXEDn3gLxIW9CeXGdFFUzCIjj8m6IdAQ7GA4XfCk="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
        "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
      ];
    };
    gc = {
      automatic = true;
      dates = [ "05:00" ];
      options = "--delete-older-than 3d";
    };
    optimise = {
      automatic = true;
      dates = [ "05:00" ];
    };
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  programs = {
    nix-ld = {
      enable = true;
    };
  };

  system = {
    rebuild = {
      enableNg = true;
    };
  };
}
