{nixclyx}: _: let
  inherit (nixclyx) sources loadFlake;
in {
  imports =
    [
      (loadFlake sources.stylix).nixOnDroidModules.stylix
    ]
    ++ nixclyx.lib.fs.collectSpecs nixclyx.lib.modules.mkModule ./.;

  config = {
    _module.args.nixclyx = nixclyx;

    nixpkgs = {
      overlays = [nixclyx.overlays.default];
      config.allowUnfree = true;
    };

    nix.extraOptions = ''
      experimental-features = nix-command flakes
    '';

    system.stateVersion = "24.05";
  };
}
