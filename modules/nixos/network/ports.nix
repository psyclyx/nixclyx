{
  path = ["psyclyx" "nixos" "network" "ports"];
  gate = "always";
  options = {lib, ...}: let
    portEntry = lib.types.coercedTo
      (lib.types.either lib.types.port (lib.types.listOf lib.types.port))
      (v: if builtins.isList v then {tcp = v;} else {tcp = [v];})
      (lib.types.submodule {
        options = {
          tcp = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [];
            description = "TCP ports.";
          };
          udp = lib.mkOption {
            type = lib.types.listOf lib.types.port;
            default = [];
            description = "UDP ports.";
          };
        };
      });
  in lib.mkOption {
    type = lib.types.attrsOf portEntry;
    default = {};
    description = ''
      Service port registry. Services declare the ports they use here.
      Pure data — does not open ports or affect the firewall.
      Consumers (firewall glue, monitoring, etc.) read from it.
    '';
  };
  config = {};
}
