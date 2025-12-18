{ inputs, config, ... }:
{
  imports = [ ./base.nix ];

  config = {
    networking.hostName = "lab-2";
  };
}
