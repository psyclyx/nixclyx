{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.darwin.programs.raycast;
in {
  options.psyclyx.darwin.programs.raycast = {
    enable = lib.mkEnableOption "Raycast launcher";
  };

  config = lib.mkIf cfg.enable {
    homebrew.casks = ["raycast"];
  };
}
