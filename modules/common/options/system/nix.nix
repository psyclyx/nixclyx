{nixclyx, lib, pkgs, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "common" "system" "nix"];
  description = "nix configuration";
  config = _: let
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
} args
