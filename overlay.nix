let
  sources = import ./npins;
  loadFlake = import ./loadFlake.nix;

  colmena = loadFlake sources.colmena;
  astal = loadFlake sources.astal;
in
  _: prev: {
    psyclyx = import ./packages {pkgs = prev;};
    colmena = colmena.packages.${prev.stdenv.hostPlatform.system};
    astal = astal.packages.${prev.stdenv.hostPlatform.system};
  }
