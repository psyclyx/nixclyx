let
  sources = import ./npins;
  loadFlake = import ./loadFlake.nix;

  colmena = loadFlake sources.colmena;
  astal = loadFlake sources.astal;
  clj-nix = loadFlake sources.clj-nix;
  llm-agents = loadFlake sources."llm-agents.nix";
in
  final: prev: ((llm-agents.overlays.shared-nixpkgs final prev)
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
      # wlroots' ICC output color transform (render/color_lcms2.c) builds the
      # lcms2 transform as INTENT_RELATIVE_COLORIMETRIC with no flags — i.e. no
      # black point compensation — so display shadows below the panel's black
      # floor clip to black instead of being scaled in. Enable BPC so shadow
      # detail is preserved. Used by the psyclyx_color_management_v1 ICC path in
      # the river fork.
      wlroots_0_20 = prev.wlroots_0_20.overrideAttrs (old: {
        # lib.unique guards against this overlay being applied more than once
        # (which would append the patch twice and fail as already-applied).
        patches = prev.lib.unique ((old.patches or []) ++ [./patches/wlroots-icc-bpc.patch]);
      });
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
