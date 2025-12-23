{
  config,
  lib,
  inputs,
  ...
}:
let
  inherit (lib) mkEnableOption mkIf;
  cfg = config.psyclyx.nixos.system.home-manager;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  options = {
    psyclyx.nixos.system.home-manager = {
      enable = mkEnableOption "home-manager config";
    };
  };

  config = mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = { inherit inputs; };
    };
  };
}
