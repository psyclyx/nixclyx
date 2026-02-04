{
  config,
  lib,
  ...
}: let
  cfg = config.psyclyx.darwin.system.nixpkgs;
in {
  options.psyclyx.darwin.system.nixpkgs = {
    enable = lib.mkEnableOption "nixpkgs config";
  };

  config = lib.mkIf cfg.enable {
    psyclyx.common.system.nixpkgs.enable = true;
  };
}
