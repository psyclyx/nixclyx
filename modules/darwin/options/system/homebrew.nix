{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs.stdenv) hostPlatform;

  cfg = config.psyclyx.darwin.system.homebrew;
in {
  options.psyclyx.darwin.system.homebrew = {
    enable = lib.mkEnableOption "homebrew config";
  };

  config = lib.mkIf cfg.enable {
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
