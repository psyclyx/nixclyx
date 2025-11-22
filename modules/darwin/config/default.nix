{ inputs, ... }:
let
  inherit (inputs) self;
in
{
  imports = [
    self.commonModules.config
    ./programs
    ./roles
    ./services
    ./stylix.nix
    ./system
  ];
}
