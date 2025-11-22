{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.system.security;
in
{
  options = {
    psyclyx.system.security = {
      enable = lib.mkEnableOption "security settings";
    };
  };

  config = lib.mkIf cfg.enable {
    security = {
      pam.services.sudo_local.touchIdAuth = true;
    };
  };
}
