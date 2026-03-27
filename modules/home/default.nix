{nixclyx}: let
  inherit (nixclyx) sources loadFlake;
in
  {...}: {
    imports =
      [
        (import sources.nvf).homeManagerModules.default
        "${sources.sops-nix}/modules/home-manager/sops.nix"
        "${sources.shoal}/nix/hm-module.nix"
        "${sources.tidepool}/nix/hm-module.nix"
        (import "${sources.emacs}/hm-module.nix" {})
      ]
      ++ nixclyx.lib.fs.collectSpecs nixclyx.lib.modules.mkModule ./.;

    config = {
      _module.args.nixclyx = nixclyx;
      home.stateVersion = "25.11";
    };
  }
