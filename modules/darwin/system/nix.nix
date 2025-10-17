{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.psyclyx.system.nix;

  inherit (inputs) self;
in
{
  imports = [ self.commonModules.nix ];

  config = lib.mkIf cfg.enable {
    nix.settings.trusted-users = [ "@admin" ];
  };
}
