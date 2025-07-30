{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.programs.aspell;
in
{
  options.psyclyx.programs.aspell.enable = lib.mkEnableOption "aspell + english dicts";
  config.environment = lib.mkIf cfg.enable {
    wordlist.enable = true;
    systemPackages = [
      (pkgs.aspellWithDicts (
        dicts: with dicts; [
          en
          en-computers
          en-science
        ]
      ))
    ];
  };
}
