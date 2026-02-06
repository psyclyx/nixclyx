let
  sources = import ./npins;
  loadFlake = import ./loadFlake.nix;

  colmena = loadFlake sources.colmena;
  astal = loadFlake sources.astal;
  clj-nix = loadFlake sources.clj-nix;
in
  _: prev: {
    psyclyx = import ./packages {pkgs = prev;};
    colmena = colmena.packages.${prev.stdenv.hostPlatform.system};
    astal = astal.packages.${prev.stdenv.hostPlatform.system};
    clj-nix = clj-nix.packages.${prev.stdenv.hostPlatform.system};
  }
