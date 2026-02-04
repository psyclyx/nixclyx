{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.darwin.system.security;
in {
  options.psyclyx.darwin.system.security = {
    enable = lib.mkEnableOption "security settings";
  };

  config = lib.mkIf cfg.enable {
    security = {
      pam.services.sudo_local.touchIdAuth = true;
    };
  };
}
