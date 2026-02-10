{nixclyx}: _: let
  inherit (nixclyx) modules sources loadFlake;
in {
  imports =
    [
      "${sources.home-manager}/nixos"
      (loadFlake sources.stylix).nixosModules.stylix
      modules.common.options
    ]
    ++ nixclyx.lib.fs.collectSpecs nixclyx.lib.modules.mkModule ./.;

  config = {
    _module.args.nixclyx = nixclyx;
    system.stateVersion = "25.11";
  };
}
