{
  nix-darwin,
  nixpkgs,
  ...
} @ deps: let
  applyDeps = module: nixpkgs.lib.modules.importApply module deps;
  hosts = {
    halo.modules = [(applyDeps ./halo)];
  };
in
  builtins.mapAttrs (_: nix-darwin.darwinSystem) hosts
