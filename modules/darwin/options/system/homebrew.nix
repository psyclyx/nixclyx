{
  path = ["psyclyx" "darwin" "system" "homebrew"];
  description = "homebrew config";
  config = {pkgs, ...}: let
    inherit (pkgs.stdenv) hostPlatform;
  in {
    homebrew = {
      enable = true;

      caskArgs.no_quarantine = true;

      global.autoUpdate = true;

      onActivation = {
        upgrade = false;
        autoUpdate = false;
        cleanup = "zap";
      };
    };

    nix-homebrew = {
      enable = true;
      autoMigrate = true;
      enableRosetta = hostPlatform.isAarch64;
      mutableTaps = true;
    };
  };
}
