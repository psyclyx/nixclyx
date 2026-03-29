let
  hosts = (import ./hosts/lab.nix) // (import ./hosts/infra.nix);
  devices = (import ./devices/switches.nix) // (import ./devices/aps.nix);
in {
  topology = {
    conventions = {
      gatewayOffset = 1;
      transitVlan = 250;
      adminSshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPK+1GlLeOjyDZjcdGFXjDnJfgtO7OOOoeTliAwZRSsf psyc@sigil"
      ];
    };
    domains = import ./domains.nix;
    wireguard = import ./wireguard.nix;
    ipv6UlaPrefix = "fd9a:e830:4b1e";
    inherit hosts;
    haGroups = import ./ha.nix;
    networks = import ./networks.nix;
  };

  inherit devices;
}
