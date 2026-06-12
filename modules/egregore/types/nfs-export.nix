# Entity type: NFS export.
#
# A path on a producer host exported over NFS to a set of consumer
# hosts on a specific network. The fleet's projection generates both
# the server-side exports (services.nfs.server.exports) and the
# client-side mounts (fileSystems.<mountpoint>) from the same record.
{
  egregoreType = { lib, ... }: {
    name = "nfs-export";
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
          Network entity the export server binds on and consumers
          mount via. Drives the producer's listen address + the
          mount-target FQDN. Required for real exports (asserted
          non-empty below); the empty default exists so consumers
          serializing the whole entity tree don't trip the
          option-without-default check on non-nfs-export entities.
        '';
      };
      consumerNetwork = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Network entity to look up consumer source addresses for the
          server's export ACL. Default = `network`, used when the
          consumer connects from the same VLAN it mounts via. Override
          when the consumer's L3-routed source IP lives on a different
          network (e.g. sigil mounts via storage VLAN for the 10G
          path but its source IP is on main).
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
      sec = lib.mkOption {
        type = lib.types.enum [ "sys" "krb5" "krb5i" "krb5p" ];
        default = "sys";
        description = ''
          NFSv4 sec= class. `sys` = traditional UID/GID, no Kerberos.
          `krb5` = Kerberos auth only. `krb5i` = auth + integrity (MAC
          on every RPC). `krb5p` = auth + integrity + privacy
          (encryption). Used by both server (export sec= clause) and
          client (mount -o sec=).
        '';
      };
      listenNetwork = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Network entity whose producer address this export binds to.
          Null = bind to the network field's producer address (the
          default behavior). Set distinctly when an export should
          listen on a different L3 interface than the transport network
          would suggest — e.g. a krb5i export reaching off-rack clients
          via BGP-advertised /32 instead of the storage-VLAN L2 IP.
        '';
      };
      advertiseAs = lib.mkOption {
        type = lib.types.enum [ "vlan-svi" "bgp32" "wg" ];
        default = "vlan-svi";
        description = ''
          How clients reach the export's listen address. `vlan-svi` =
          regular VLAN SVI routing on the producer's network gateway
          (default; assumes clients are on the same broadcast domain or
          a routed path exists). `bgp32` = producer advertises the
          listen address as a /32 over BGP; mdf-agg01 (or wherever the
          BGP peer is) federates the route. `wg` = reached over the WG
          overlay; no L3 advertisement needed.
        '';
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
        listenNetwork = if n.listenNetwork != null then n.listenNetwork else n.network;
        inherit (n) sec advertiseAs;
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
  };
}
