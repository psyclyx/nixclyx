{ lib, ... }:
let
  mkChecks =
    {
      nixosConfigurations ? { },
      darwinConfigurations ? { },
    }:
    let
      nixosBySystem = lib.groupBy (v: v.config.config.nixpkgs.system) (
        lib.mapAttrsToList (name: config: { inherit name config; }) nixosConfigurations
      );
      darwinBySystem = lib.groupBy (v: v.config.pkgs.system) (
        lib.mapAttrsToList (name: config: { inherit name config; }) darwinConfigurations
      );

      mkSystemChecks =
        system:
        let
          nixosChecks = lib.listToAttrs (
            map (v: lib.nameValuePair "nixos-${v.name}" v.config.config.system.build.toplevel) (
              nixosBySystem.${system} or [ ]
            )
          );
          darwinChecks = lib.listToAttrs (
            map (v: lib.nameValuePair "darwin-${v.name}" v.config.system.build.toplevel) (
              darwinBySystem.${system} or [ ]
            )
          );
        in
        nixosChecks // darwinChecks;

      allSystems = lib.unique (
        (lib.attrNames nixosBySystem) ++ (lib.attrNames darwinBySystem)
      );
    in
    lib.genAttrs allSystems mkSystemChecks;
in
{
  inherit mkChecks;
}
