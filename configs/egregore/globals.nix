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
    };

    ipv6UlaPrefix = "fd9a:e830:4b1e";

    iscsi = {
      baseIqn = "iqn.2026-05.net.psyclyx";
    };

    openbao = {
      serverHost = "iyr";
      serverNetwork = "infra";
      port = 8200;
      scheme = "https";
    };
  };
}
