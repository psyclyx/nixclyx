{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  substituters = [
    "https://psyclyx.cachix.org?priority=0"
    "https://nix-community.cachix.org?priority=1"
  ];
  trusted-substituters = substituters ++ [
    "https://nixos-raspberrypi.cachix.org?priority=3"
  ];

  cfg = config.psyclyx.system.nix;
in
{
  options = {
    psyclyx.system.nix = {
      enable = lib.mkEnableOption "Nix (actually Lix) config";
    };
  };

  config = lib.mkIf cfg.enable {
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
  };

}
