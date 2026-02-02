{
  #niri,
  stylix,
  nixclyx,
  home-manager,
  nvf,
  ...
} @ deps: {lib, ...}: {
  imports = [
    #    niri.nixosModules.niri
    stylix.nixosModules.stylix
    nixclyx.commonModules.nixos
    home-manager.nixosModules.home-manager
    nvf.nixosModules.default
    ./boot
    ./filesystems
    ./hardware
    ./network
    ./programs
    ./services
    ./system
  ];

  options = {
    psyclyx.nixos = {
      deps = lib.mkOption {
        type = lib.types.attrsOf lib.types.unspecified;
        default = {};
      };
    };
  };

  config = {
    psyclyx.nixos = {inherit deps;};
    system.stateVersion = "25.11";
  };
}
