{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.tools.misc;
in
{
  options = {
    psyclyx = {
      tools = {
        misc = {
          enable = lib.mkEnableOption "Misc. shell tools";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        fd
        htop
        jet
        jq
        ripgrep
      ];
    };
  };
}
