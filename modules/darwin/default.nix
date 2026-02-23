{nixclyx}: _: let
  inherit (nixclyx) modules sources loadFlake;
in {
  imports =
    [
      "${sources.home-manager}/nix-darwin"
      (loadFlake sources.stylix).darwinModules.stylix
      (loadFlake sources.nix-homebrew).darwinModules.nix-homebrew
      modules.common.options
    ]
    ++ nixclyx.lib.fs.collectSpecs nixclyx.lib.modules.mkModule ./.;

  config = {
    _module.args.nixclyx = nixclyx;
    system.stateVersion = 5;
  };
}
