{ inputs, ... }:
let
  inherit (inputs) self stylix;
in
{
  imports = [
    stylix.darwinModules.stylix
    self.commonModules.config
    ./programs
    ./roles
    ./services
    ./system
  ];
}
