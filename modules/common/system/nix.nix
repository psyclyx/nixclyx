{
  path = ["psyclyx" "common" "system" "nix"];
  description = "nix configuration";
  config = {
    pkgs,
    nixclyx,
    ...
  }: {
    nix = {
      package = pkgs.lix;

      settings = {
        inherit (nixclyx.nixCaches) substituters trusted-substituters trusted-public-keys;
        connect-timeout = 5;
        experimental-features = [
          "nix-command"
          "flakes"
        ];

        http-connections = 0;
        max-jobs = 4;
        trusted-users = ["@builders"];
      };

      # Weekly gc + optimise. The schedule options differ per platform
      # (NixOS `dates`, nix-darwin `interval`), so each platform's nix
      # module sets them.
      gc = {
        automatic = true;
        options = "--delete-older-than 7d";
      };

      optimise.automatic = true;
    };
  };
}
