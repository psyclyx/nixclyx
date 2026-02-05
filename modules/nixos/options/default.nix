{nixclyx}: _: let
  inherit (nixclyx) modules sources loadFlake;
in {
  imports =
    [
      "${sources.home-manager}/nixos"
      (import sources.nvf).nixosModules.default
      (loadFlake sources.stylix).nixosModules.stylix
      (modules.common.options {inherit nixclyx;})
    ]
    ++ nixclyx.lib.fs.collectModules ./.;

  config = {
    system.stateVersion = "25.11";
  };
}
