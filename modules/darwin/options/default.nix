{nixclyx}: _: let
  inherit (nixclyx) modules sources loadFlake;
in {
  imports =
    [
      "${sources.home-manager}/nix-darwin"
      (loadFlake sources.stylix).darwinModules.stylix
      (loadFlake sources.nix-homebrew).darwinModules.nix-homebrew
      (modules.common.options {inherit nixclyx;})
      (modules.common.psyclyx {inherit nixclyx;})
    ]
    ++ nixclyx.lib.fs.collectModules ./.;

  config = {
    system.stateVersion = 5;
    _module.args = {inherit nixclyx;};
  };
}
