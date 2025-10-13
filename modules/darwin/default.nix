{ inputs, ... }:
{
  imports = [
    ./programs
    ./roles
    ./services
    ./stylix.nix
    ./system
  ];
}
