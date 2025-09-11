{ pkgs }:
let
  inherit (pkgs) callPackage lib system;
  platforms = import ./platforms.nix;
in
rec {
  defSupported = packageDef: lib.elem system (def.platforms or platforms.all);
  callDef = packageDef: callPackage packageDef.path { };
  supportedDefs = packageDefs: lib.filterAttrs (_name: def: defSupported def) packageDefs;
  mkPackageSet = packageDefs: lib.mapAttrs (_name: def: callDef def) (supportedDefs packageDefs);
}
