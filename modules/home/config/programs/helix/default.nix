{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib) getExe mkEnableOption mkIf;

  cfg = config.psyclyx.programs.helix;
in
{
  options = {
    psyclyx.programs.helix = {
      enable = mkEnableOption "helix text editor";
    };
  };

  config = mkIf cfg.enable {
    programs.helix = {
      enable = true;

      languages.language = [
        {
          name = "nix";
          auto-format = true;
          formatter.command = getExe pkgs.nixfmt;
        }
      ];
    };
  };
}
