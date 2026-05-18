# Entity type: NFS export.
#
# A path on a producer host exported over NFS to a set of consumer
# hosts on a specific network. The fleet's projection generates both
# the server-side exports (services.nfs.server.exports) and the
# client-side mounts (fileSystems.<mountpoint>) from the same record.
{
  lib,
  egregorLib,
  config,
  ...
}:
egregorLib.mkType {
  name = "nfs-export";
  topConfig = config;
  description = "NFS share — one path on a producer, mounted by listed consumers.";

  options = {
    path = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Path on the producer that's exported. Required for real
        exports (asserted non-empty below) — default is "" only so
        non-nfs-export entities don't trip the option-without-default
        check when consumers serialize the whole entity tree.
      '';
    };
    network = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Network entity carrying the NFS traffic. Required for real
        exports (asserted non-empty below); the empty default exists
        so consumers serializing the whole entity tree don't trip the
        option-without-default check on non-nfs-export entities.
      '';
    };
    consumers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Host entity names allowed to mount this export.";
    };
    readOnly = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
    mountAt = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Mountpoint on each consumer. Null means consumers don't get an
        automatic fileSystems entry — the export is reachable but
        mounting is handled elsewhere (e.g. per-host substitution of a
        $hostname segment).
      '';
    };
    options = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "noatime" "nodiratime" ];
      description = "Mount options on the consumer side.";
    };
  };

  attrs =
    name: entity: _top:
    let
      n = entity.nfs-export;
    in
    {
      label = "${entity.refs.producer or "<?>"}:${n.path} → ${toString (builtins.length n.consumers)} client(s)";
      producer = entity.refs.producer or null;
    };

  assertions =
    name: entity: top:
    let
      n = entity.nfs-export;
      producer = entity.refs.producer or null;
    in
    [
      {
        assertion = producer != null;
        message = "nfs-export '${name}' requires refs.producer";
      }
      {
        assertion = producer == null || (top.entities ? ${producer} && top.entities.${producer}.type == "host");
        message = "nfs-export '${name}' producer '${toString producer}' must be a host entity";
      }
      {
        assertion = n.network != "";
        message = "nfs-export '${name}' requires a non-empty network";
      }
      {
        assertion = n.network == "" || (top.entities ? ${n.network} && top.entities.${n.network}.type == "network");
        message = "nfs-export '${name}' network '${n.network}' must be a network entity";
      }
      {
        assertion = n.path != "";
        message = "nfs-export '${name}' requires a non-empty path";
      }
    ]
    ++ map (c: {
      assertion = top.entities ? ${c} && top.entities.${c}.type == "host";
      message = "nfs-export '${name}' consumer '${c}' must be a host entity";
    }) n.consumers;
}
