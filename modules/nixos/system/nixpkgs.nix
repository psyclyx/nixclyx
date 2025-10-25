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
    psyclyx.system.nixpkgs.enable = lib.mkEnableOption "nixpkgs config (includes allowUnfree and accepts nvidia license)";
  };

  config = lib.mkIf cfg.enable {
    nixpkgs = inputs.self.lib.nixpkgs.pkgsOptions;
  };
}
