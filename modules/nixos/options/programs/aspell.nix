{
  path = ["psyclyx" "nixos" "programs" "aspell"];
  description = "aspell + english dicts";
  options = {
    lib,
    pkgs,
    ...
  }: {
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

    finalPackage = lib.mkPackageOption pkgs "aspell-with-dicts" {};
  };
  config = {
    cfg,
    lib,
    pkgs,
    ...
  }: {
    psyclyx.nixos.programs.aspell.finalPackage = lib.mkDefault (pkgs.aspellWithDicts cfg.dictionaries);
    environment = {
      wordlist.enable = true;
      systemPackages = [cfg.finalPackage];
    };
  };
}
