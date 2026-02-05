{nixclyx}: let
  inherit (nixclyx) sources loadFlake;
in
  {...}: {
    imports =
      [
        (loadFlake sources.ags).homeManagerModules.ags
        "${sources.sops-nix}/modules/home-manager/sops.nix"
      ]
      ++ nixclyx.lib.fs.collectModules ./.;

    config = {
      home.stateVersion = "25.11";
    };
  }
