{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.services.greetd;
in
{
  options.psyclyx.services.greetd.enable = lib.mkEnableOption "greetd+regreet";
  config = lib.mkIf cfg.enable {
    programs.regreet.enable = true;
  };
}
