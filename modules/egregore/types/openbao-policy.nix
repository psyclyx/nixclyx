# Entity type: OpenBao policy.
#
# A named policy expressed as data. Rules can be listed explicitly,
# or implied via `kvReader` (a list of kv-secret entity names this
# policy is allowed to read — the projection expands these into the
# matching `read` capabilities on data/metadata paths).
{
  lib,
  egregorLib,
  config,
  ...
}:
egregorLib.mkType {
  name = "openbao-policy";
  topConfig = config;
  description = "An OpenBao policy declared as fleet data.";

  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Policy name in OpenBao. Required for real policies (asserted
        non-empty); empty default exists so non-policy entities don't
        trip the option-without-default check.
      '';
    };
    rules = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            path = lib.mkOption {
              type = lib.types.str;
              description = "OpenBao path, e.g. \"pki/issue/foo\".";
            };
            capabilities = lib.mkOption {
              type = lib.types.listOf (
                lib.types.enum [
                  "create"
                  "read"
                  "update"
                  "patch"
                  "delete"
                  "list"
                  "sudo"
                  "deny"
                  "subscribe"
                ]
              );
            };
          };
        }
      );
      default = [ ];
      description = "Explicit policy rules. Combined with kvReader-derived rules.";
    };
    kvReader = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Names of kv-secret entities this policy is allowed to read.
        The projection expands each into `read` on the secret's
        data/metadata paths.
      '';
    };
  };

  attrs =
    name: entity: top:
    let
      p = entity.openbao-policy;
      kvSecretEntities = lib.filterAttrs (_: e: e.type == "kv-secret") top.entities;
      kvReaderRules = lib.flatten (
        map (
          secretName:
          let
            secret = kvSecretEntities.${secretName} or null;
          in
          if secret == null then [ ]
          else [
            {
              path = secret.attrs.dataPath;
              capabilities = [ "read" ];
            }
            {
              path = secret.attrs.metadataPath;
              capabilities = [
                "read"
                "list"
              ];
            }
          ]
        ) p.kvReader
      );
      effectiveRules = p.rules ++ kvReaderRules;
      hcl = lib.concatStringsSep "\n" (
        map (r:
          ''path "${r.path}" { capabilities = [${
            lib.concatMapStringsSep ", " (c: "\"${c}\"") r.capabilities
          }] }''
        ) effectiveRules
      );
    in
    {
      label = p.name;
      inherit effectiveRules hcl;
    };

  assertions =
    name: entity: top:
    let
      p = entity.openbao-policy;
    in
    [
      {
        assertion = p.name != "";
        message = "openbao-policy '${name}' requires a non-empty name";
      }
    ]
    ++ map (sn: {
      assertion = top.entities ? ${sn} && top.entities.${sn}.type == "kv-secret";
      message = "openbao-policy '${name}' kvReader '${sn}' is not a kv-secret entity";
    }) p.kvReader;
}
