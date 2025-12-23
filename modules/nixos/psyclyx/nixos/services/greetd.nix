{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.services.greetd;
in
{
  options = {
    psyclyx.nixos.services.greetd = {
      enable = mkEnableOption "greetd+regreet";
    };
  };

  config = mkIf cfg.enable {
    programs.regreet = {
      enable = true;
      cageArgs = [
        "-m"
        "last"
        "-s"
      ];
    };
  };
}
