rec {
  nixos = ./nixos;
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
