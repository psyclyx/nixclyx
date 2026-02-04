{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.darwin.programs.firefox;
in {
  options.psyclyx.darwin.programs.firefox = {
    enable = lib.mkEnableOption "Firefox browser";
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = ["firefox"];
  };
}
