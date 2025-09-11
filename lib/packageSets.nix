{ pkgs }:
let
  inherit (pkgs) callPackage lib system;
  systems = import ./systems.nix;
in
rec {
  mkPackageSet =
    let
      defSupported = packageDef: lib.elem system (packageDef.systems or systems.all);
      callDef = packageDef: callPackage packageDef.path { };
      supportedDefs = packageDefs: lib.filterAttrs (_name: def: defSupported def) packageDefs;
    in
    packageDefs: lib.mapAttrs (_name: def: callDef def) (supportedDefs packageDefs);
}
