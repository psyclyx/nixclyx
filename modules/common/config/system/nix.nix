{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) filterAttrs mapAttrs;

  cfg = config.psyclyx.system.nix;

  substituters = [
    "https://nix-community.cachix.org?priority=1"
  ];

  trusted-substituters = [
    "https://psyclyx.cachix.org?priority=10"
  ];

  trusted-public-keys = [
    "psyclyx.cachix.org-1:UFwKXEDn3gLxIW9CeXGdFFUzCIjj8m6IdAQ7GA4XfCk="
    "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
  ];
in
{
  options = {
    psyclyx.system.nix = {
      enable = lib.mkEnableOption "Nix config";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.nh
      pkgs.nix-output-monitor
      pkgs.nix-tree
      pkgs.nixfmt-tree
    ];

    nix = {
      package = pkgs.lix;

      registry =
        let
          isFlake = input: input._type or null == "flake";
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

        http-connections = 0;

        max-jobs = 4;

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
