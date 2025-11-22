let
  inherit (builtins) mapAttrs readDir;

  dirToAttrSet =
    dir:
    let
      entryValue =
        name: type:
        let
          name' = "${dir}/${name}";
          directory = type == "directory";
        in
        if directory then dirToAttrSet name' else name';
    in
    mapAttrs entryValue (readDir dir);
in
dirToAttrSet ./.
