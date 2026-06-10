# Egregore → openbao endpoint URL projection.
#
# Reads `eg.openbao` globals (serverHost + serverNetwork + port +
# scheme) and exposes the resulting URL at `psyclyx.openbao.endpoint`
# so downstream consumers (openbao-login, openbao-kv, openbao-vm-auth)
# don't each re-derive it.
{config, lib, ...}: {
  options.psyclyx.openbao.endpoint = lib.mkOption {
    type = lib.types.str;
    default = "";
    description = ''
      URL to reach the fleet OpenBao listener (e.g.
      https://10.0.25.1:8200). Empty if the fleet's `eg.openbao`
      globals are unset or the named serverHost has no address on
      serverNetwork.
    '';
  };

  config = let
    eg = config.psyclyx.egregore;
    obo = eg.openbao or {};
    serverHost = obo.serverHost or "";
    serverNet = obo.serverNetwork or "";
    addr = lib.attrByPath
      ["entities" serverHost "attrs" "addresses" serverNet "ipv4"] "" eg;
  in lib.mkIf (addr != "") {
    psyclyx.openbao.endpoint =
      "${obo.scheme or "https"}://${addr}:${toString (obo.port or 8200)}";
  };
}
