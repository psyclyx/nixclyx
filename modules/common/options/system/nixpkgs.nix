{nixclyx, lib, ...} @ args:
nixclyx.lib.modules.mkModule {
  path = ["psyclyx" "common" "system" "nixpkgs"];
  description = "nixpkgs config (unfree, etc)";
  gate = false;
  config = {cfg, lib, ...}: lib.mkMerge [
    {nixpkgs.overlays = [nixclyx.overlays.default];}

    (lib.mkIf cfg.enable {
      nixpkgs.config = {
        allowUnfree = true;
        nvidia.acceptLicense = true;
      };
    })
  ];
} args
