{ pkgs }:
let
  inherit (pkgs) callPackage lib;
  inherit (pkgs.stdenv.hostPlatform) system;
  inherit (lib) elem filterAttrs mapAttrs;

  supported =
    package:
    !(package.meta ? platforms) || package.meta.platforms == [ ] || elem system package.meta.platforms;

  callPackages = packageDefs: mapAttrs (_: packageDef: callPackage packageDef { }) packageDefs;

  filterSupported = packages: filterAttrs (_: supported) packages;

  packageDefs = {
    print256colors = ./print256colors.nix;
    ssacli = ./ssacli.nix;
    upscale-image = ./upscale-image;
  };
in
filterSupported (callPackages packageDefs)
