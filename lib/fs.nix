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
  # --- Spec collection and compilation ---

  # Shared helpers for variant processing.
  _last = l: builtins.elemAt l (builtins.length l - 1);
  _init = l: builtins.genList (builtins.elemAt l) (builtins.length l - 1);
  _groupBy = f:
    builtins.foldl' (acc: x: let
      k = f x;
    in
      acc // {${k} = (acc.${k} or []) ++ [x];}) {};

  # Discover spec files and import them, returning raw spec attrsets.
  # callSpec controls how each discovered path is turned into a spec —
  # defaults to builtins.import, but can inject arguments (e.g. secrets).
  collectRawSpecs = {
    root,
    callSpec ? builtins.import,
  }:
    map callSpec (collectModules root);

  # Process a list of raw specs: separate variants, generate enum options,
  # and compile everything through mkModule into NixOS modules.
  compileSpecs = mkModule: specs: let
    variantSpecs = builtins.filter (s: s ? variant) specs;
    regularSpecs = builtins.filter (s: !(s ? variant)) specs;

    groups = _groupBy (s: builtins.concatStringsSep "." s.variant) variantSpecs;

    enumSpecs = map (key: let
      group = groups.${key};
      variant = (builtins.head group).variant;
      parentPath = _init variant;
      optName = _last variant;
      names = map (s: _last s.path) group;
    in {
      path = parentPath;
      gate = "always";
      options = {lib, ...}: {
        ${optName} = lib.mkOption {
          type = lib.types.enum names;
        };
      };
    }) (builtins.attrNames groups);
  in
    map mkModule (regularSpecs ++ variantSpecs ++ enumSpecs);

  # Like collectModules, but imports each path as a spec, handles
  # variant grouping (auto-generating enum options), wraps with mkModule,
  # and returns the resulting NixOS modules.
  # Preserved for backward compatibility — existing call sites pass a
  # (possibly wrapping) mkModule function and a root directory.
  collectSpecs = mkModule: root:
    compileSpecs mkModule (collectRawSpecs { inherit root; });

  # Recursively collect module-importable paths from a directory tree.
  # Returns .nix files (except default.nix) as imports, and directories
  # with a default.nix as leaf imports (the module system loads default.nix).
  # Directories without default.nix are recursed into transparently.
  collectModules = root:
    tree.mkTree (
      tree.filterChildren
      (_: name: type:
        type == "directory" || (hasSuffix ".nix" name && name != "default.nix"))
      ((fsSpec root)
        // {
          branch = path: type:
            type
            == "directory"
            && (path == [] || !(builtins.pathExists (toPath root path + "/default.nix")));
          onBranch = _: _: kids:
            builtins.concatLists
            (map ({result, ...}:
              if builtins.isList result
              then result
              else [result])
            kids);
        })
    );

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
