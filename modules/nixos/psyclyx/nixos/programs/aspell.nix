{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.nixos.programs.aspell;
in
{
  options = {
    psyclyx.nixos.programs.aspell = {
      enable = lib.mkEnableOption "aspell + english dicts";
      dictionaries = lib.mkOption {
        description = "Function returning dictionaries to include with aspell.";
        type = lib.types.functionTo (lib.types.listOf lib.types.package);
        default = dicts: [
          dicts.en
          dicts.en-computers
          dicts.en-science
        ];

        defaultText = "dicts: [dicts.en dicts.en-computers dicts.en-science]";
      };

      finalPackage = lib.mkPackageOption pkgs "aspell-with-dicts" { };
    };
  };

  config = lib.mkIf cfg.enable {
    psyclyx.nixos.programs.aspell.finalPackage = lib.mkDefault (pkgs.aspellWithDicts cfg.dictionaries);
    environment = {
      wordlist.enable = true;
      systemPackages = [ cfg.finalPackage ];
    };
  };
}
