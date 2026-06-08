# Entity type: tang server.
#
# A tang HTTP key-server running on some host. Clevis bindings declare
# which tangs they trust; the storage / firewall / DNS projections all
# read this entity to wire up the producer side and discover URLs for
# clients. Cheap, single-instance today, but typed for fleet
# queryability ("which hosts serve tang?") and for cleanly adding
# redundancy later (declare another tang-server and add it to a
# clevis-binding's tangs list).
{
  egregoreType = { lib, ... }: {
    name = "tang-server";
    description = "A tang server (network presence + HTTP port) on a host.";

    options = {
      port = lib.mkOption {
        type = lib.types.port;
        default = 80;
        description = "HTTP port tang listens on.";
      };
      network = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Network entity whose host address advertises the tang URL to
          clients. Required (asserted non-empty); the empty default
          exists so non-tang entities don't trip the option-without-
          default check. The projection resolves the host's address on
          this network to build the URL.
        '';
      };
    };

    attrs =
      name: entity: top:
      let
        t = entity.tang-server;
        host = entity.refs.host or null;
        hostEnt = if host == null then null else top.entities.${host} or null;
        addr =
          if hostEnt == null then null
          else ((hostEnt.attrs.addresses or { }).${t.network} or { }).ipv4 or null;
      in
      {
        label = "tang @ ${toString host}:${toString t.port}";
        producer = host;
        url = if addr == null then null else "http://${addr}:${toString t.port}";
      };

    assertions =
      name: entity: top:
      let
        t = entity.tang-server;
        host = entity.refs.host or null;
      in
      [
        {
          assertion = host != null;
          message = "tang-server '${name}' requires refs.host";
        }
        {
          assertion = host == null || (top.entities ? ${host} && top.entities.${host}.type == "host");
          message = "tang-server '${name}' refs.host '${toString host}' must be a host entity";
        }
        {
          assertion = t.network != "";
          message = "tang-server '${name}' requires a non-empty network";
        }
        {
          assertion = t.network == "" || (top.entities ? ${t.network} && top.entities.${t.network}.type == "network");
          message = "tang-server '${name}' network '${t.network}' must be a network entity";
        }
      ];
  };
}
