{ config, lib, ... }:
let
  inherit (lib) mkIf;
in
{
  config = mkIf config.psyclyx.nixos.system.nix.enable {
    nix.settings.trusted-users = [ "@wheel" ];
  };
}
