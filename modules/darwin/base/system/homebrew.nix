{
  config,
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs)
    nix-homebrew
    homebrew-bundle
    homebrew-core
    homebrew-cask
    ;
  inherit (pkgs.stdenv) hostPlatform;
in
{
  imports = [ nix-homebrew.darwinModules.nix-homebrew ];

  homebrew = {
    enable = true;

    caskArgs.no_quarantine = true;

    global.autoUpdate = true;

    onActivation = {
      upgrade = false;
      autoUpdate = false;
      cleanup = "zap";
    };

    taps = builtins.attrNames (
      builtins.removeAttrs config.nix-homebrew.taps [
        "homebrew/bundle"
        "homebrew/core"
        "homebrew/cask"
      ]
    );
  };

  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    enableRosetta = hostPlatform.isAarch64;
    mutableTaps = true;
    taps = {
      "homebrew/bundle" = homebrew-bundle;
      "homebrew/core" = homebrew-core;
      "homebrew/cask" = homebrew-cask;
    };
  };
}
