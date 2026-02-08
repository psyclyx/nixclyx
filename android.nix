let
  sources = import ./npins;

  mkAndroid = {config}: {
    build = import sources.robotnix config;
    inherit config;
    __functor = _: args: mkAndroid {config = config // args.config or {};};
  };
  mkAndroids = {configs}: (builtins.mapAttrs (_: config: mkAndroid {inherit config;}) configs) // {__functor = _: args: mkAndroid {configs = configs // args.configs or {};};};
in
  mkAndroid
  {
    configs = {
      pixel9pro = {
        configuration = {
          device = "caiman";
          flavor = "grapheneos";
          grapheneos.release = "2026020600";

          microg.enable = true;
          apps.fdroid.enable = true;
          apps.seedvault.enable = true;
          apps.updater.enable = true;
        };
      };
    };
  }
