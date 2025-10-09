{ lib, ... }:
let
  dirToAttrset =
    dir:
    let
      entries = builtins.readDir dir;
    in
    builtins.mapAttrs (
      name: type: if type == "directory" then dirToAttrset (dir + "/${name}") else dir + "/${name}"
    ) entries;
in
{
  inherit dirToAttrset;
}
