{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.tools.python;
in
{
  options = {
    psyclyx = {
      tools = {
        python = {
          enable = lib.mkEnableOption "Python tools";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    home = {
      packages = with pkgs; [ python3 ];
    };
  };
}
