{
  inputs,
  pkgs,
  ...
}:
let
  inherit (pkgs) lib;

  psyclyx = inputs.self;
in
{
  imports = [
    psyclyx.nixosModules.psyclyx
  ];

  config = {

    networking.domain = "rack.home.psyclyx.net";

    psyclyx = {
      hardware = {
        cpu = {
          intel.enable = true;
          enableMitigations = false;
        };
        hpe.enable = true;
      };

      roles = {
        base.enable = true;
        remote.enable = true;
        utility.enable = true;
      };
    };

    nix.settings.trusted-users = [ "psyc" ];

    users = {
      users = {
        psyc = {
          name = "psyc";
          home = "/home/psyc";
          shell = pkgs.zsh;
          isNormalUser = true;

          extraGroups = [
            "wheel"
            "builders"
          ];
          openssh.authorizedKeys.keys = psyclyx.common.keys.psyc.openssh;
        };
        root.openssh.authorizedKeys.keys = psyclyx.common.keys.psyc.openssh;
      };
    };

    home-manager.users.psyc = {
      imports = [ ../../../home/psyc.nix ];

      psyclyx.configs.psyc = {
        enable = true;
        server = true;
      };
    };
  };

}
