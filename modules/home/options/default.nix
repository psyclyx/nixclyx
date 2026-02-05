{nixclyx}: let
  inherit (nixclyx) sources loadFlake;
in
  {...}: {
    imports =
      [
        (loadFlake sources.ags).homeManagerModules.ags
        "${sources.sops-nix}/modules/home-manager/sops.nix"
      ]
      ++ nixclyx.lib.fs.collectSpecs nixclyx.lib.modules.mkModule ./.;

    config = {
      _module.args.nixclyx = nixclyx;
      home.stateVersion = "25.11";
    };
  }
