{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.psyclyx.nixos.system.home-manager;
in
{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];

  options = {
    psyclyx.nixos.system.home-manager = {
      enable = lib.mkEnableOption "home-manager config";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = { inherit inputs; };
    };
  };
}
