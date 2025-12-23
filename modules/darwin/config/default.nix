{ inputs, lib, ... }:
let
  inherit (inputs) self stylix;
in
{
  imports = [
    stylix.darwinModules.stylix
    self.commonModules.darwin
    ./programs
    ./roles
    ./services
    ./system
  ];
}
