{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.darwin.system.nix;
in
{
  config = lib.mkIf cfg.enable {
    nix.settings.trusted-users = [ "@admin" ];
  };
}
