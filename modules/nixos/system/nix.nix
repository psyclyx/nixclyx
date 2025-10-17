{
  config,
  inputs,
  lib,
  ...
}:
let
  inherit (inputs) self;

  cfg = config.psyclyx.system.nix;
in
{
  imports = [ self.commonModules.nix ];

  config = lib.mkIf cfg.enable {
    nix.settings.trusted-users = [ "@wheel" ];

    programs.nix-ld.enable = true;

    system.rebuild.enableNg = true;
  };
}
