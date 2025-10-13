{
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.psyclyx.system.home-manager;
in
{
  imports = [ inputs.home-manager.darwinModules.home-manager ];

  options = {
    psyclyx.system.home-manager = {
      enable = lib.mkEnableOption "home-manager config";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager = {
      sharedModules = [ inputs.self.homeManagerModules.psyclyx ];
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = { inherit inputs; };
    };
  };
}
