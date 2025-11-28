{ inputs, ... }:
{
  imports = [ inputs.self.nixosModules.config ];

  config = {
    networking.hostName = "harp";

    psyclyx = {
      network.ports.ssh = [ 17891 ];

      network.enable = true;

      roles = {
        base.enable = true;
        remote.enable = true;
        utility.enable = true;
      };

      users.psyc = {
        enable = true;
      };
    };
  };
}
