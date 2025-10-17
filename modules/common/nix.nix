{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) filterAttrs mapAttrs;
  inherit (inputs) self;

  cfg = config.psyclyx.system.nix;

  substituters = [
    "https://psyclyx.cachix.org?priority=0"
    "https://nix-community.cachix.org?priority=1"
  ];

  trusted-substituters = substituters ++ [
    "https://nixos-raspberrypi.cachix.org?priority=3"
  ];

  trusted-public-keys = [
    "psyclyx.cachix.org-1:UFwKXEDn3gLxIW9CeXGdFFUzCIjj8m6IdAQ7GA4XfCk="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
  ];
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

      registry =
        let
          isFlake = input: input._type == "flake";
          flakeInputs = filterAttrs (_: isFlake) inputs;
          registrySet = flakeInput: { flake = flakeInput; };
        in
        mapAttrs (_: registrySet) flakeInputs;

      settings = {
        inherit substituters trusted-substituters trusted-public-keys;

        experimental-features = [
          "nix-command"
          "flakes"
        ];

        trusted-users = [ "@builders" ];

        http-connections = 128;

        connect-timeout = 5;
      };

      gc = {
        automatic = true;
        dates = [ "05:00" ];
        options = "--delete-older-than 7d";
      };

      optimise = {
        automatic = true;
        dates = [ "06:00" ];
      };
    };
  };

}
