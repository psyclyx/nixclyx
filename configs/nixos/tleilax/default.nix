{ inputs, ... }:
{
  imports = [
    inputs.self.nixosModules.config
    ./filesystem.nix
    ./network.nix
  ];

  config = {
    networking.hostName = "tleilax";

    psyclyx = {
      network.ports.ssh = [ 17891 ];

      hardware.presets.hpe.dl20-gen10.enable = true;

      roles = {
        base.enable = true;
        remote.enable = true;
        utility.enable = true;
      };

      services = {
        tailscale.exitNode = true;
      };

      users.psyc = {
        enable = true;
        server = true;
      };
    };
  };
}
