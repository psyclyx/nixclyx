{
  stylix,
  nixclyx,
  home-manager,
  nix-homebrew,
  ...
}@deps:
{ lib, ... }:
{
  imports = [
    stylix.darwinModules.stylix
    nixclyx.commonModules.darwin
    home-manager.darwinModules.home-manager
    nix-homebrew.darwinModules.nix-homebrew
    ./programs
    ./roles
    ./services
    ./system
  ];

  options = {
    psyclyx.darwin.deps = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = { };
    };
  };

  config = {
    psyclyx.darwin = { inherit deps; };
  };
}
