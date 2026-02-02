# fs.nix — Filesystem utilities built on tree.nix
#
# Provides composable spec combinators for directory traversal,
# and pre-composed specs for common patterns.
let
  tree = import ./tree.nix;
in rec {
  # Convert an attrPath to a real path under root.
  toPath = root: attrPath:
    builtins.foldl' (p: name: p + "/${name}") root attrPath;

  # --- Base specs ---

  # Base filesystem traversal spec. Recurses into directories,
  # visits all entries. No opinion on onLeaf/onBranch.
  fsSpec = root: {
    seed = "directory";
    branch = _: type: type == "directory";
    children = path: _:
      tree.attrsToList (builtins.readDir (toPath root path));
    onLeaf = path: _: toPath root path;
    onBranch = _: _: kids: tree.listToNamedAttrs kids;
  };

  # --- Spec combinators ---

  # Only include children whose key matches a file extension (e.g. ".nix").
  # Directories are always kept.
  filterExt = ext:
    tree.filterChildren (_: key: entry:
      entry == "directory" || hasSuffix ext key);

  # Strip a file extension from child keys.
  stripExt = ext: spec:
    spec
    // {
      onBranch = path: entry: kids:
        spec.onBranch path entry
        (map ({
            key,
            result,
          }: {
            key = removeSuffix ext key;
            inherit result;
          })
          kids);
    };

  # Treat directories containing default.nix as leaves instead of recursing.
  stopAtDefault = root: spec:
    spec
    // {
      branch = path: type:
        type
        == "directory"
        && !(builtins.pathExists (toPath root path + "/default.nix"));
      onLeaf = path: type:
        if type == "directory"
        then import (toPath root path + "/default.nix")
        else spec.onLeaf path type;
    };

  # Replace onLeaf with importing the file.
  importLeaves = root: spec:
    spec
    // {
      onLeaf = path: _: import (toPath root path);
    };

  # Exclude specific filenames.
  excludeNames = names:
    tree.filterChildren (_: key: _:
      !(builtins.elem key names));

  # --- Composed utilities ---

  # Turn a directory into a nested attrset of paths.
  #   assets/wallpapers/foo.jpg -> { assets.wallpapers."foo.jpg" = /abs/path; }
  dirToAttrs = root:
    tree.mkTree (fsSpec root);

  # Import all .nix files in a directory tree as a nested attrset,
  # keyed by filename without extension. Directories with default.nix
  # are imported as a single value, not recursed into.
  importDir = root:
    tree.mkTree (
      stopAtDefault root
      (importLeaves root
        (stripExt ".nix"
          (filterExt ".nix"
            (fsSpec root))))
    );

  # Treats directories with ./default.nix as 'regular', stopping traversal.
  collapseDefaultNix = root: spec:
    spec
    // {
      children = path: entry:
        map (
          {
            key,
            entry,
          }:
            if
              entry
              == "directory"
              && builtins.pathExists (toPath root (path ++ [key]) + "/default.nix")
            then {
              inherit key;
              entry = "regular";
            }
            else {
              inherit key;
              entry = entry;
            }
        ) (spec.children path entry);
    };
  # --- String helpers (no nixpkgs dependency) ---

  hasSuffix = suffix: str: let
    slen = builtins.stringLength suffix;
    len = builtins.stringLength str;
  in
    len
    >= slen
    && builtins.substring (len - slen) slen str == suffix;

  removeSuffix = suffix: str: let
    slen = builtins.stringLength suffix;
    len = builtins.stringLength str;
  in
    if hasSuffix suffix str
    then builtins.substring 0 (len - slen) str
    else str;
}
