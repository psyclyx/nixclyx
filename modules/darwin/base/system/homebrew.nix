{
  pkgs,
  inputs,
  ...
}:
let
  inherit (inputs) nix-homebrew;
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
  };

  nix-homebrew = {
    enable = true;
    autoMigrate = true;
    enableRosetta = hostPlatform.isAarch64;
    mutableTaps = true;
  };
}
