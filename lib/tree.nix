rec {
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
