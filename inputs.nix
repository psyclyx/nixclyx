let
  pins = import ./npins;
  loadFlake = src:
    (import pins.flake-compat {
      inherit src;
      copySourceTreeToStore = false;
    }).outputs;
in {
  zsh-pure = pins.zsh-pure;

  nixpkgs = loadFlake pins.nixpkgs;
  nix-darwin = loadFlake pins.nix-darwin;
  home-manager = loadFlake pins.home-manager;
  colmena = loadFlake pins.colmena;
  sops-nix = loadFlake pins.sops-nix;
  nix-homebrew = loadFlake pins.nix-homebrew;
  stylix = loadFlake pins.stylix;
  ags = loadFlake pins.ags;
  astal = loadFlake pins.astal;
  nvf = loadFlake pins.nvf;
  #  niri = loadFlake pins.niri;
}
