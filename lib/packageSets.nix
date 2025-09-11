{ pkgs }:
let
  inherit (pkgs) lib callPackage;
  platforms = import ./platforms.nix;
in
rec {
  mkPackageSet = packageDefs: (lib.mapAttrs (_name: def: lib.callPackage def.path { }) packageDefs);
  supportedPackages =
    system: packageDefs:
    (lib.filterAttrs (_name: def: lib.elem system (def.platforms or platforms.all)) packageDefs);
  mkSupportedPackageSet = system: packageDefs: (mkPackageSet (supportedPackages system));
}
