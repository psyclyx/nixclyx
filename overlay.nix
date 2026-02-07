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

    bitwig-studio4 = prev.bitwig-studio4.overrideAttrs (old: rec {
      version = "4.1.6";
      src = prev.fetchurl {
        url = "https://downloads.bitwig.com/stable/${version}/${old.pname}-${version}.deb";
        sha256 = "sha256-Q4YYdMUd/T8tGGcakhoLdHvWsHwOq7LgIb77sr2OWuQ=";
      };
    });
  }
