{nixclyx}: _: let
  inherit (nixclyx) modules sources loadFlake;
in {
  imports = [
    "${sources.home-manager}/nix-darwin"
    (loadFlake sources.stylix).darwinModules.stylix
    (loadFlake sources.nix-homebrew).darwinModules.nix-homebrew
    modules.common.options
    modules.common.psyclyx
    ./programs
    ./services
    ./system
  ];

  config = {
    system.stateVersion = 5;
    _module.args = {inherit nixclyx;};
  };
}
