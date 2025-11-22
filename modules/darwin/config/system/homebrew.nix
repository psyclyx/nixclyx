{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) nix-homebrew;
  inherit (pkgs.stdenv) hostPlatform;

  cfg = config.psyclyx.system.homebrew;
in
{
  imports = [ nix-homebrew.darwinModules.nix-homebrew ];

  options = {
    psyclyx.system.homebrew = {
      enable = lib.mkEnableOption "homebrew config";
    };
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
