{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkDefault
    mkEnableOption
    mkIf
    mkOption
    mkPackageOption
    types
    ;

  cfg = config.psyclyx.nixos.programs.aspell;
in
{
  options = {
    psyclyx.nixos.programs.aspell = {
      enable = mkEnableOption "aspell + english dicts";
      dictionaries = mkOption {
        description = "Function returning dictionaries to include with aspell.";
        type = types.functionTo (types.listOf types.package);
        default = dicts: [
          dicts.en
          dicts.en-computers
          dicts.en-science
        ];

        defaultText = "dicts: [dicts.en dicts.en-computers dicts.en-science]";
      };

      finalPackage = mkPackageOption pkgs "aspell-with-dicts" { };
    };
  };

  config = mkIf cfg.enable {
    psyclyx.nixos.programs.aspell.finalPackage = mkDefault (pkgs.aspellWithDicts cfg.dictionaries);
    environment = {
      wordlist.enable = true;
      systemPackages = [ cfg.finalPackage ];
    };
  };
}
