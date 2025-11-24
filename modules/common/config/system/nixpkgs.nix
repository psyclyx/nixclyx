{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.psyclyx.system.nixpkgs;
in
{
  options = {
    psyclyx.system.nixpkgs.enable = lib.mkEnableOption "nixpkgs config (unfree, etc)";
  };

  config = lib.mkMerge [
    { nixpkgs.overlays = [ inputs.self.overlays.default ]; }

    (lib.mkIf cfg.enable {
      nixpkgs = {
        config = {
          allowUnfree = true;
          nvidia.acceptLicense = true;
        };
        overlays = [ inputs.self.overlays.default ];
      };
    })
  ];

}
