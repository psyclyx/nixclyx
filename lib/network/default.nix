{ lib, psyclyxLib, ... }:
let
  inherit (builtins)
    catAttrs
    map
    removeAttrs
    toString
    ;

  inherit (lib)
    filterAttrs
    genList
    hasPrefix
    listToAttrs
    mkMerge
    mkOption
    pipe
    types
    ;

  genInterfaces =
    {
      base ? { },
      prefix,
      start ? 1,
      count ? 1,
    }@spec:
    let
      mkInterface =
        i:
        let
          idx = toString (i + start);
        in
        {
          name = "${prefix}${idx}";
          value = base;
        };

      interfaceList = listToAttrs (genList mkInterface count);
    in
    listToAttrs (genList mkInterface count);

  modules = {

    interface =
      { config, name, ... }:
      {
        options = {
          portType = mkOption {
            type = types.enum [
              "patch"
              "rj45"
              "sfp"
              "sfp+"
              "qsfp"
            ];
          };
        };
      };

    interfaces =
      { config, ... }:
      {
        options = {
          _generate = mkOption {
            type = types.listOf (
              types.submodule (
                { config, ... }:
                {
                  options = {
                    base = mkOption { type = types.submodule modules.interface; };
                    prefix = mkOption { type = types.str; };
                    start = mkOption { type = types.ints.unsigned; };
                    count = mkOption { type = types.ints.positive; };

                    _finalModule = mkOption {
                      internal = true;
                      readOnly = true;
                      type = types.deferredModule;
                    };
                  };

                  config._finalModule = genInterfaces config;
                }
              )
            );
          };
        };

        freeformType = types.attrsOf modules.interface;

        config = mkMerge (catAttrs "_finalModule" config);

      };
  };
in

{
  inherit genInterfaces types modules;
}
