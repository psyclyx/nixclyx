rec {
  getPath = attrs: path: builtins.foldl' (attrs: attr: attrs.${attr}) attrs path;
  fromPaths = items: let
    # separate leaf values from items that need deeper nesting
    leaves = builtins.filter (i: builtins.length i.path == 1) items;
    branches = builtins.filter (i: builtins.length i.path > 1) items;

    # group branches by first key
    grouped = builtins.groupBy (i: builtins.head i.path) branches;

    # recurse into each group with tail paths
    nested =
      builtins.mapAttrs (
        _: group:
          fromPaths (map (i: {
              path = builtins.tail i.path;
              inherit (i) value;
            })
            group)
      )
      grouped;

    # leaf entries as flat attrs
    leafAttrs = builtins.listToAttrs (map (i: {
        name = builtins.head i.path;
        value = i.value;
      })
      leaves);
  in
    nested // leafAttrs;
}
