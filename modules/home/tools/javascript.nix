{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.tools.javascript;
in
{
  options = {
    psyclyx = {
      tools = {
        javascript = {
          enable = lib.mkEnableOption "Javascript tools";
        };
      };
    };
  };
  config = lib.mkIf cfg.enable {
    home = {
      packages = with pkgs; [
        eclint
        nodejs
        nodePackages.prettier
        nodePackages.typescript
        nodePackages.typescript-language-server
      ];
    };
  };
}
