{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.programs.raycast;
in
{
  options = {
    psyclyx.programs.raycast = {
      enable = lib.mkEnableOption "Raycast launcher";
    };
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = [ "raycast" ];
  };
}
