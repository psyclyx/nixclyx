{ nixpkgs, ... }@deps:
rec {
  nixos = nixpkgs.lib.modules.importApply ./nixos deps;
  roles = ./roles;
  users = ./users;
  default =
    { ... }:
    {
      imports = [
        nixos
        roles
        users
      ];
    };
}
