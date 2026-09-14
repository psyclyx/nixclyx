# The full nixclyx overlay = internal producer overlays composed under
# nixclyx's own overlay (./overlay.nix). Factored out so every pkgs path
# (the module-system overlay via overlays.default, hive's meta.nixpkgs via
# nixpkgs.nix, and shell.nix) applies the same composed overlay.
#
# `sources` is the (possibly injected) source set — see default.nix's
# internalSources seam. Standalone it's nixclyx's own npins; the monorepo
# superproject overrides the internal-producer entries with sibling checkouts,
# so the producers built here track the monorepo versions.
{
  sources ? import ./npins,
}:
let
  # emacs-unstable-pgtk for the emacs home-manager module, which no longer
  # applies emacs-overlay itself. Sourced from emacs's own pin (single
  # version of record) rather than a separate nixclyx pin.
  emacsOverlay = import (import (sources.emacs + "/npins")).emacs-overlay;

  producerOverlays = [
    emacsOverlay
    (import sources.river { }).overlay # patched wlroots_0_20 + river + set-output-icc
    (import sources.shoal { }).overlay
    (import sources.tidepool { }).overlay
    (import sources.base24-gen { }).overlay
    (import sources.fix { }).overlay
  ];

  own = import ./overlay.nix;

  inherit ((import (sources.nixpkgs + "/lib"))) composeManyExtensions;
in
composeManyExtensions (producerOverlays ++ [ own ])
