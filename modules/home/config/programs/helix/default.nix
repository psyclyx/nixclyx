{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.programs.helix;
in
{
  options = {
    psyclyx.programs.helix = {
      enable = lib.mkEnableOption "helix text editor";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.helix = {
      enable = true;
      languages.language = [
        {
          name = "nix";
          auto-format = true;
          formatter = {
            command = lib.getExe pkgs.nixfmt;
            args = [ "--strict" ];
          };
        }
      ];
    };
  };
}
