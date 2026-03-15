let
  tree = import ./tree.nix;
in rec {
  toPath = root: attrPath:
    builtins.foldl' (p: name: p + "/${name}") root attrPath;

  fsSpec = root: {
    seed = "directory";
    branch = _: type: type == "directory";
    children = path: _:
      tree.attrsToList (builtins.readDir (toPath root path));
    onLeaf = path: _: toPath root path;
    onBranch = _: _: kids: tree.listToNamedAttrs kids;
  };

  filterExt = ext:
    tree.filterChildren (_: key: entry:
      entry == "directory" || hasSuffix ext key);

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

  importLeaves = root: spec:
    spec
    // {
      onLeaf = path: _: import (toPath root path);
    };

  excludeNames = names:
    tree.filterChildren (_: key: _:
      !(builtins.elem key names));

  # Treats directories with ./default.nix as 'regular' files, stopping traversal.
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
  _last = l: builtins.elemAt l (builtins.length l - 1);
  _init = l: builtins.genList (builtins.elemAt l) (builtins.length l - 1);
  _groupBy = f:
    builtins.foldl' (acc: x: let
      k = f x;
    in
      acc // {${k} = (acc.${k} or []) ++ [x];}) {};

  # callSpec controls how each discovered path is turned into a spec —
  # defaults to builtins.import, but can inject arguments (e.g. secrets).
  collectRawSpecs = {
    root,
    callSpec ? builtins.import,
  }:
    map callSpec (collectModules root);

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

  collectSpecs = mkModule: root:
    compileSpecs mkModule (collectRawSpecs { inherit root; });

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
