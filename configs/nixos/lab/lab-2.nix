{ inputs, config, ... }:
{
  imports = [ ./base.nix ];

  config = {
    networking.hostName = "lab-2";
    psyclyx = {
      filesystems.layouts.bcachefs-pool.UUID = {
        root = "2d2c95b3-cad6-4d9c-b11c-fe8abe7b8014";
        boot = "208E-CA68";
      };
    };
  };
}
