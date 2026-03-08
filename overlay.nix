let
  sources = import ./npins;

  colmena = loadFlake sources.colmena;
  astal = loadFlake sources.astal;
  clj-nix = loadFlake sources.clj-nix;
  loadFlake = import ./loadFlake.nix;
  llm-agents = loadFlake sources."llm-agents.nix";
in
  final: prev: ((llm-agents.overlays.default final prev)
    // {
      psyclyx = import ./packages {pkgs = prev;};
      colmena = colmena.packages.${prev.stdenv.hostPlatform.system};
      astal = astal.packages.${prev.stdenv.hostPlatform.system};
      clj-nix = clj-nix.packages.${prev.stdenv.hostPlatform.system};
      # python-etcd tests are broken on Python 3.13 (getheader removed from HTTPResponse)
      pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [(pyFinal: pyPrev: {
        python-etcd = pyPrev.python-etcd.overridePythonAttrs { doCheck = false; };
      })];
      # __multf3 (128-bit float multiply) missing on aarch64 — link libgcc_s
      pam_ssh_agent_auth = prev.pam_ssh_agent_auth.overrideAttrs (old: prev.lib.optionalAttrs prev.stdenv.hostPlatform.isAarch64 {
        buildInputs = (old.buildInputs or []) ++ [prev.stdenv.cc.cc.lib];
      });
      bitwig-studio4 = prev.bitwig-studio4.overrideAttrs (old: rec {
        version = "4.1.6";
        src = prev.fetchurl {
          url = "https://downloads.bitwig.com/stable/${version}/${old.pname}-${version}.deb";
          sha256 = "sha256-Q4YYdMUd/T8tGGcakhoLdHvWsHwOq7LgIb77sr2OWuQ=";
        };
      });
    })
