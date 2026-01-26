{
  config,
  lib,
  ...
}:
let
  cfg = config.psyclyx.nixos.services.greetd;
in
{
  options = {
    psyclyx.nixos.services.greetd = {
      enable = lib.mkEnableOption "greetd+regreet";
    };
  };

  config = lib.mkIf cfg.enable {
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
