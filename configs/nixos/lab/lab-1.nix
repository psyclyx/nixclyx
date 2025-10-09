{ ... }:
{
  imports = [ ./common.nix ];

  config = {
    networking = {
      hostName = "lab-1";
    };
  };
}
