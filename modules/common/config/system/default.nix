{moduleGroup ? "common"}: {lib, ...}: {
  imports = map (modulePath: lib.modules.importApply modulePath {inherit moduleGroup;}) [
    ./nixpkgs.nix
    ./nix.nix
    ./stylix.nix
  ];
}
