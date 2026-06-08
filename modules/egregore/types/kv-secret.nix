# Entity type: OpenBao KV secret.
#
# A single KV v2 path declared as data. The producer host is the one
# whose plaintext source file feeds the KV write at deploy time
# (typically the OpenBao server reading sops-decrypted files into
# its own KV mount). Consumer-side fetch is handled separately via
# `openbao-kv` on the reading host.
{
  egregoreType = { lib, ... }: {
    name = "kv-secret";
    description = "An OpenBao KV v2 secret seeded from a source file.";

    options = {
      mount = lib.mkOption {
        type = lib.types.str;
        default = "kv";
        description = "KV v2 mount name on the OpenBao server.";
      };
      path = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = ''
          Path under the mount (no leading slash). Required for real
          secrets (asserted non-empty below). Empty default exists so
          non-kv-secret entities don't trip the option-without-default
          check when the registry is serialized.
        '';
      };
      sourceFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Plaintext file on the producer host whose contents become the
          KV value. Typically a sops-decrypted secret path. Null means
          the KV path is referenced but not seeded by this entity (the
          value lands via some other mechanism).
        '';
      };
      valueField = lib.mkOption {
        type = lib.types.str;
        default = "value";
        description = ''
          Field name within the KV v2 record holding the secret value.
          Consumers read this via `jq -r '.<field>'` against `.data.data`.
        '';
      };
    };

    attrs =
      name: entity: _top:
      let
        s = entity.kv-secret;
      in
      {
        fullPath = "${s.mount}/${s.path}";
        # The path consumers use in policies for read capability.
        dataPath = "${s.mount}/data/${s.path}";
        metadataPath = "${s.mount}/metadata/${s.path}";
        producer = entity.refs.producer or null;
        label = "${s.mount}/${s.path}";
      };

    assertions =
      name: entity: top:
      let
        s = entity.kv-secret;
        producer = entity.refs.producer or null;
      in
      [
        {
          assertion = s.path != "";
          message = "kv-secret '${name}' requires a non-empty path";
        }
        {
          assertion = producer != null;
          message = "kv-secret '${name}' requires refs.producer (the host whose sops secret feeds the KV write)";
        }
        {
          assertion = producer == null || (top.entities ? ${producer} && top.entities.${producer}.type == "host");
          message = "kv-secret '${name}' producer '${toString producer}' must be a host entity";
        }
      ];
  };
}
