{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.tools.nix;
in
{
  options = {
    psyclyx = {
      tools = {
        nix = {
          enable = lib.mkEnableOption "Nix (language) tools";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        nixd
        nixfmt-rfc-style
      ];
    };
  };
}
