{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.system.nix;
in
{
  config = lib.mkIf cfg.enable {
    nix.settings.trusted-users = [ "@admin" ];
  };
}
