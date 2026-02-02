let
  mkAssets = {lib ? import ../lib}: let
    inherit (lib.tree) mkTree;
    inherit (lib.fs) excludeNames fsSpec;
    spec = excludeNames ["default.nix"] (fsSpec ./.);
  in
    mkTree spec;
in
  (mkAssets {}) // {__functor = _: mkAssets;}
