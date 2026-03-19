let
  sources = import ./npins;
  loadFlake = import ./loadFlake.nix;

  colmena = loadFlake sources.colmena;
  astal = loadFlake sources.astal;
  clj-nix = loadFlake sources.clj-nix;
  llm-agents = loadFlake sources."llm-agents.nix";
in
  final: prev: ((llm-agents.overlays.default final prev)
    // {
      psyclyx = import ./packages {pkgs = prev;};
      shoal = final.psyclyx.shoal;
      colmena = colmena.packages.${prev.stdenv.hostPlatform.system};
      astal = astal.packages.${prev.stdenv.hostPlatform.system};
      clj-nix = clj-nix.packages.${prev.stdenv.hostPlatform.system};
      # python-etcd tests are broken on Python 3.13 (getheader removed from HTTPResponse)
      pythonPackagesExtensions =
        prev.pythonPackagesExtensions
        ++ [
          (pyFinal: pyPrev: {
            python-etcd = pyPrev.python-etcd.overridePythonAttrs {doCheck = false;};
          })
        ];
      # __multf3 (128-bit float multiply) missing on aarch64 — the Makefile
      # calls ld directly (bypassing the CC wrapper), so buildInputs alone
      # won't add libgcc_s to the rpath.  Patch the .so after build instead.
      pam_ssh_agent_auth = prev.pam_ssh_agent_auth.overrideAttrs (old:
        prev.lib.optionalAttrs prev.stdenv.hostPlatform.isAarch64 {
          postFixup = (old.postFixup or "") + ''
            patchelf --add-needed libgcc_s.so.1 \
                     --add-rpath ${prev.stdenv.cc.cc.lib}/lib \
                     $out/libexec/pam_ssh_agent_auth.so
          '';
        });
      rofi-rbw = prev.rofi-rbw.overrideAttrs {
        src = prev.fetchFromGitHub {
          owner = "psyclyx";
          repo = "rofi-rbw";
          rev = "psyclyx/feat-fuzzel-keybindings";
          hash = "sha256-+BtxrbAqEUhyRGdWocH36A01oKYAnScSLljgu6oPMxs=";
        };
      };
      bitwig-studio4 = prev.bitwig-studio4.overrideAttrs (old: rec {
        version = "4.1.6";
        src = prev.fetchurl {
          url = "https://downloads.bitwig.com/stable/${version}/${old.pname}-${version}.deb";
          sha256 = "sha256-Q4YYdMUd/T8tGGcakhoLdHvWsHwOq7LgIb77sr2OWuQ=";
        };
      });
    })
