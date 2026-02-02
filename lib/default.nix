let
  tree = import ./tree.nix;
  fs = import ./fs.nix;
in
  tree.mkTree (
    fs.excludeNames ["default.nix"]
    (fs.collapseDefaultNix ./.
      (fs.stripExt ".nix"
        (fs.importLeaves ./.
          (fs.filterExt ".nix"
            (fs.fsSpec ./.)))))
  )
