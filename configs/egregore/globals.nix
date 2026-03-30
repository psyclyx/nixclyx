# Global configuration values for the psyclyx fleet.
{
  gate = "always";
  config = {
    conventions = {
      gatewayOffset = 1;
      transitVlan = 250;
      adminSshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPK+1GlLeOjyDZjcdGFXjDnJfgtO7OOOoeTliAwZRSsf psyc@sigil"
      ];
    };

    domains = {
      internal = "psyclyx.net";
      public   = "psyclyx.xyz";
      home     = "home.psyclyx.net";
    };

    ipv6UlaPrefix = "fd9a:e830:4b1e";

    overlay = {
      subnet = "10.157.0.0/24";
      port   = 51820;
      hub    = "tleilax";
    };
  };
}
