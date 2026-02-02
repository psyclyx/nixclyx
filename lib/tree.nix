# tree.nix — Generic tree recursion scheme with composable traversal specs.
#
# A "spec" is an attrset of callbacks passed to mkTree:
#   seed:     Initial entry for the root node.
#   branch:   attrPath -> entry -> bool. Decides whether to recurse.
#   children: attrPath -> entry -> list of {key, entry}. Discovers children.
#   onLeaf:   attrPath -> entry -> result. Produces a value at leaves.
#   onBranch: attrPath -> entry -> list of {key, result} -> result. Assembles branch results.
#
# Combinators modify specs before they reach mkTree, so composition is always single-pass.
rec {
  # Run a traversal spec, producing a single result value.
  mkTree = {
    seed,
    branch ? _: _: true,
    children,
    onLeaf ? _: entry: entry,
    onBranch ? _: _: children: children,
  }: let
    go = path: entry:
      if branch path entry
      then let
        kids = children path entry;
        results =
          map (
            {
              key,
              entry,
            }: {
              inherit key;
              result = go (path ++ [key]) entry;
            }
          )
          kids;
      in
        onBranch path entry results
      else onLeaf path entry;
  in
    go [] seed;

  # Transform leaf results.
  mapLeaves = f: spec:
    spec
    // {
      onLeaf = path: entry: f path (spec.onLeaf path entry);
    };

  # Transform branch results after assembly.
  mapBranches = f: spec:
    spec
    // {
      onBranch = path: entry: kids: f path (spec.onBranch path entry kids);
    };

  # Transform all results (leaves and branches).
  mapResults = f: spec:
    mapLeaves (_: f) (mapBranches (_: f) spec);

  # Filter children before recursing.
  filterChildren = pred: spec:
    spec
    // {
      children = path: entry:
        builtins.filter ({
          key,
          entry,
        }:
          pred path key entry)
        (spec.children path entry);
    };

  # Convert an attrset to the list-of-pairs representation used by children.
  attrsToList = attrs:
    map (name: {
      key = name;
      entry = attrs.${name};
    })
    (builtins.attrNames attrs);

  # Convert a list of {key, result} pairs back to an attrset.
  listToNamedAttrs = kids:
    builtins.listToAttrs
    (map ({
        key,
        result,
      }: {
        name = key;
        value = result;
      })
      kids);
}
