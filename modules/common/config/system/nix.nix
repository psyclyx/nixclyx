{moduleGroup ? "common"}: {
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.psyclyx.${moduleGroup}.system.nix;

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
in {
  options = {
    psyclyx.${moduleGroup}.system.nix = {
      enable = lib.mkEnableOption "Nix config";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.nh
      pkgs.niv
      pkgs.nix-output-monitor
      pkgs.nix-tree
      pkgs.nixfmt-tree
      pkgs.npins
    ];

    nix = {
      package = pkgs.lix;

      settings = {
        inherit substituters trusted-substituters trusted-public-keys;
        connect-timeout = 5;
        experimental-features = [
          "nix-command"
          "flakes"
        ];

        http-connections = 0;
        max-jobs = 4;
        trusted-users = ["@builders"];
      };

      gc = {
        automatic = true;
        dates = ["05:00"];
        options = "--delete-older-than 7d";
      };

      optimise = {
        automatic = true;
        dates = ["06:00"];
      };
    };
  };
}
