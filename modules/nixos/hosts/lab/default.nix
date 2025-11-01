{
  base =
    { config, ... }:
    {
      imports = [ ./base.nix ];
      config = {
        networking.hostName = "lab-base";
        users.users.root.openssh.authorizedKeys.keys = config.users.users.psyc.openssh.authorizedKeys.keys;
      };
    };

  lab-1 = {
    imports = [ ./base.nix ];
    config = {
      networking.hostName = "lab-1";
    };
  };

  lab-2 = {
    imports = [ ./base.nix ];
    config = {
      networking.hostName = "lab-2";
    };
  };

  lab-3 = {
    imports = [ ./base.nix ];
    config = {
      networking.hostName = "lab-3";
    };
  };

  lab-4 = {
    imports = [ ./base.nix ];
    config = {
      networking.hostName = "lab-4";
    };
  };
}
