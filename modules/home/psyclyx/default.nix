{ ags, sops-nix, ... }@deps:
{ lib, ... }:
{
  imports = [
    ags.homeManagerModules.default
    sops-nix.homeManagerModules.sops
    ./home
  ];

  options = {
    psyclyx.home.deps = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = { };
    };
  };

  config = {
    psyclyx.home = { inherit deps; };
  };
}
