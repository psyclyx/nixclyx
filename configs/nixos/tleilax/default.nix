{ inputs, ... }:
{
  imports = [
    inputs.self.nixosModules.psyclyx
    ./filesystem.nix
    ./network.nix
  ];

  config = {
    networking.hostName = "tleilax";

    psyclyx = {
      nixos = {
        services = {
          tailscale.exitNode = true;
        };
      };

      network.ports.ssh = [ 17891 ];

      hardware.presets.hpe.dl20-gen10.enable = true;

      network.enable = true;

      roles = {
        base.enable = true;
        remote.enable = true;
        utility.enable = true;
      };

      users.psyc = {
        enable = true;
        server = true;
      };
    };
  };
}
