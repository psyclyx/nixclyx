# Derived OpenBao endpoint registry.
#
# Reads `eg.openbao` globals — serverHost + serverNetwork + port +
# scheme — and exposes the resulting URL as `psyclyx.openbao.endpoint`
# so consumers (openbao-login, openbao-kv, openbao-vm-auth callers,
# bootstrap scripts) don't each redo the derivation. Generic shape;
# any fleet that fills in `eg.openbao` gets a populated endpoint.
{
  path = [ "psyclyx" "openbao" ];
  gate = "always";

  options = { lib, ... }: {
    endpoint = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        URL to reach the fleet OpenBao listener
        (e.g. https://10.0.25.1:8200). Empty if the fleet's
        `eg.openbao` globals are unset or the named serverHost has
        no address on serverNetwork.
      '';
    };
  };

  config = { config, lib, ... }: let
    eg = config.psyclyx.egregore;
    obo = eg.openbao or {};
    serverHost = obo.serverHost or "";
    serverNet = obo.serverNetwork or "";
    serverEnt =
      if serverHost != "" then eg.entities.${serverHost} or null else null;
    addr =
      if serverEnt != null
      then (serverEnt.attrs.addresses.${serverNet} or {}).ipv4 or null
      else null;
  in lib.mkIf (addr != null) {
    psyclyx.openbao.endpoint =
      "${obo.scheme or "https"}://${addr}:${toString (obo.port or 8200)}";
  };
}
