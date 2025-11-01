{ inputs, ... }:
let
  inherit (inputs) self stylix;
in
{
  imports = [
    stylix.nixosModules.stylix
    self.commonModules.stylix
  ];
}
