{ inputs, ... }:
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
  stylix.image = ../../wallpapers/madoka-homura-2x.png;
}
