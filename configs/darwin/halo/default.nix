{ inputs, ... }:
let
  inherit (inputs) self;
in
{
  imports = [
    self.darwinModules.psyclyx
    ./users.nix
  ];

  psyclyx = {
    roles = {
      base.enable = true;
      desktop.enable = true;
    };
    services = {
      tailscale.enable = true;
    };
    stylix = {
      enable = true;
      image = self.assets.wallpapers."2x-ppmm-madoka-homura.png";
    };
  };

  homebrew.casks = [
    "orcaslicer"
    "google-chrome"
  ];
}
