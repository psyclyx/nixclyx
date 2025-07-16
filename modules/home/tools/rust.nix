{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.tools.rust;
in
{
  options = {
    psyclyx = {
      tools = {
        rust = {
          enable = lib.mkEnableOption "Rust tools";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        cargo
        rustc
      ];
    };
  };
}
