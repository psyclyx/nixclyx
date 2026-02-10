let
  sources = import ./npins;
  robotnix = import sources.robotnix;

  mkAndroid = config: {
    #__functor = _: mkAndroid;
    inherit config;
    build = robotnix {configuration = config.configuration;};
  };

  mkAndroids = configs:
    {
      #  __functor = _: mkAndroids;
      inherit configs;
    }
    // (builtins.mapAttrs (_: mkAndroid) configs);
in
  mkAndroids
  {
    pixel9pro = {
      configuration = {
        device = "caiman";
        flavor = "grapheneos";
        grapheneos = {
          # release = "2026020600";
          channel = "stable";
        };

        microg.enable = true;
        apps.fdroid.enable = true;
        apps.seedvault.enable = true;
        # apps.updater.enable = true;
      };
    };
  }
