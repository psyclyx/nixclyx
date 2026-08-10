let
  sources = import ./npins;
  loadFlake = import ./loadFlake.nix;

  colmena = loadFlake sources.colmena;
  astal = loadFlake sources.astal;
  clj-nix = loadFlake sources.clj-nix;
  llm-agents = loadFlake sources."llm-agents.nix";
in
  final: prev:
  let
    # Minimal asciidoc: still wires xsltproc + docbook so `a2x` emits man
    # pages, but drops the full PDF toolchain (dblatex → inkscape). Used
    # to slim the Clevis/Tang/LUKS NBDE stack below — those packages only
    # ship man pages, yet nixpkgs feeds them `asciidoc-full` (and aliases
    # `asciidoc` to it), forcing a source build of inkscape on every
    # headless host that unlocks via Tang (iyr, the lab NBDE clients).
    asciidocManpage = prev.asciidoc.override { enableStandardFeatures = false; };
  in
    ((llm-agents.overlays.shared-nixpkgs final prev)
    // {
      psyclyx =
        (import ./packages {pkgs = prev;})
        // {
          # Internal producers now come from their own overlays (composed
          # ahead of this one in ./overlays.nix), aliased under psyclyx so the
          # existing pkgs.psyclyx.* module references keep working.
          inherit (prev) river shoal tidepool set-output-icc;
          "base24-gen" = prev."base24-gen";
        };
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
      # cpplint's own test suite asserts empty stderr, but a newer Python
      # emits a codecs.open() DeprecationWarning there — broken upstream,
      # unrelated to our config.
      cpplint = prev.cpplint.overrideAttrs {
        doCheck = false;
        doInstallCheck = false;
      };
      # glasgow pins importlib-resources~=6.5.2 but nixpkgs now ships 7.1.0 —
      # upstream constraint is stale, unrelated to our config.
      glasgow = prev.glasgow.overridePythonAttrs (old: {
        pythonRelaxDeps = (old.pythonRelaxDeps or []) ++ ["importlib_resources"];
      });
      # (river's wlroots_0_20 ICC black-point-compensation patch now travels
      # with river itself — see app/river/overlay.nix — so it is applied via
      # the river producer overlay composed ahead of this one.)
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
      # Slim the NBDE stack off the inkscape-pulling PDF toolchain (see
      # asciidocManpage above). tang + clevis take `asciidoc-full`;
      # luksmeta takes `asciidoc` (which nixpkgs aliases to the -full
      # build). All three only generate man pages.
      tang = prev.tang.override { asciidoc-full = asciidocManpage; };
      clevis = prev.clevis.override { asciidoc-full = asciidocManpage; };
      luksmeta = prev.luksmeta.override { asciidoc = asciidocManpage; };
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
