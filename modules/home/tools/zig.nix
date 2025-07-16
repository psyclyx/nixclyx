{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.tools.zig;
in
{
  options = {
    psyclyx = {
      tools = {
        zig = {
          enable = lib.mkEnableOption "Zig tools";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        zig
        zls
      ];
    };
  };
}
