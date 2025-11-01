{ inputs, lib, ... }:
let
  inherit (lib) mkDefault;
in
{
  imports = inputs.self.homeManagerModules.homes.psyc.base;

  config = {
    psyclyx = {
      roles = {
        dev.enable = true;
        graphical.enable = true;
      };
      secrets.enable = mkDefault true;
    };
  };
}
