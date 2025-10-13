{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.programs.firefox;
in
{
  options = {
    psyclyx.programs.firefox = {
      enable = lib.mkEnableOption "Firefox browser";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "firefox" ];
  };
}
