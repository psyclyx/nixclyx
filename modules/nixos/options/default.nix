{nixclyx}: _: let
  inherit (nixclyx) modules sources loadFlake;
in {
  imports = [
    "${sources.home-manager}/nixos"
    (import sources.nvf).nixosModules.default
    (loadFlake sources.stylix).nixosModules.stylix
    modules.common.options
    modules.common.psyclyx
    ./boot
    ./filesystems
    ./hardware
    ./network
    ./programs
    ./services
    ./system
  ];

  config = {
    system.stateVersion = "25.11";
    _module.args = {inherit nixclyx;};
  };
}
