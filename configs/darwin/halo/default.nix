{ inputs, ... }:
let
  inherit (inputs) self disko;
in
{
  imports = [
    inputs.stylix.darwinModules.stylix
    ../../../modules/darwin/base
    ../../../modules/darwin/desktop
    ../../../modules/darwin/programs/zsh.nix
    ../../../modules/darwin/services/tailscale.nix
    ./users.nix
    ./casks.nix
  ];

  stylix.enable = true;

  stylix.image = self.assets.wallpapers."2x-ppmm-madoka-homura.png";
}
