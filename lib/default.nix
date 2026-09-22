let
  tree = import ./tree.nix;
  fs = import ./fs.nix;
in
  tree.mkTree (
    # `egregore/` and `platform/` are imported by path where they're used,
    # not collected as leaves: their files are functions, renderers, and
    # specs, not values.
    fs.excludeNames ["default.nix" "egregore" "platform"]
    (fs.collapseDefaultNix ./.
      (fs.stripExt ".nix"
        (fs.importLeaves ./.
          (fs.filterExt ".nix"
            (fs.fsSpec ./.)))))
  )
