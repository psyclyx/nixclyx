let
  sources = import ./npins;

  colmena = loadFlake sources.colmena;
  astal = loadFlake sources.astal;
  clj-nix = loadFlake sources.clj-nix;
  rustfs-flake = loadFlake sources.rustfs-flake;
  loadFlake = import ./loadFlake.nix;
  llm-agents = loadFlake sources."llm-agents.nix";
in
  final: prev: ((llm-agents.overlays.default final prev)
    // {
      psyclyx = import ./packages {pkgs = prev;};
      colmena = colmena.packages.${prev.stdenv.hostPlatform.system};
      astal = astal.packages.${prev.stdenv.hostPlatform.system};
      clj-nix = clj-nix.packages.${prev.stdenv.hostPlatform.system};
      rustfs = rustfs-flake.packages.${prev.stdenv.hostPlatform.system}.default;

      # nixpkgs deno check phase references wrong test target name
      deno = prev.deno.overrideAttrs (old: { doCheck = false; });

      bitwig-studio4 = prev.bitwig-studio4.overrideAttrs (old: rec {
        version = "4.1.6";
        src = prev.fetchurl {
          url = "https://downloads.bitwig.com/stable/${version}/${old.pname}-${version}.deb";
          sha256 = "sha256-Q4YYdMUd/T8tGGcakhoLdHvWsHwOq7LgIb77sr2OWuQ=";
        };
      });
    })
