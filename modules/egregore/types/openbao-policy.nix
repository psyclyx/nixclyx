# Entity type: OpenBao policy.
#
# A named policy expressed as data. Rules can be listed explicitly,
# or implied via `kvReader` (a list of kv-secret entity names this
# policy is allowed to read — the projection expands these into the
# matching `read` capabilities on data/metadata paths).
{
  egregoreType = { lib, ... }: {
    name = "openbao-policy";
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
      pkiIssuer = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Names of openbao-pki-role entities this policy may mint leaf
          certs from. The projection expands each into `update` on the
          role's issue path plus `read` on the mount's ca / ca_chain.
        '';
      };
      sshSigner = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Names of openbao-ssh-cert-role entities this policy may
          request signatures from. The projection expands each into
          `update` on the role's sign path.
        '';
      };
    };

    deriveOptions = {
      label = lib.mkOption { type = lib.types.str; };
      effectiveRules = lib.mkOption {
        type = lib.types.listOf (lib.types.submodule {
          options = {
            path = lib.mkOption { type = lib.types.str; default = ""; };
            capabilities = lib.mkOption {
              type = lib.types.listOf (lib.types.enum [
                "create" "read" "update" "patch" "delete" "list" "sudo" "deny" "subscribe"
              ]);
              default = [ ];
            };
          };
        });
        default = [ ];
        description = "Declared rules with kvReader/pkiIssuer/sshSigner expansions merged in.";
      };
      hcl = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "The effective policy rendered as OpenBao HCL.";
      };
    };

    derive =
      name: entity: egregore:
      let
        p = entity.openbao-policy;
        kvSecretEntities = lib.filterAttrs (_: e: e.kv-secret != null) egregore.entities;
        pkiRoleEntities = lib.filterAttrs (_: e: e.openbao-pki-role != null) egregore.entities;
        sshRoleEntities = lib.filterAttrs (_: e: e.openbao-ssh-cert-role != null) egregore.entities;
        kvReaderRules = lib.flatten (
          map (
            secretName:
            let
              secret = kvSecretEntities.${secretName} or null;
            in
            if secret == null then [ ]
            else [
              {
                path = secret.dataPath;
                capabilities = [ "read" ];
              }
              {
                path = secret.metadataPath;
                capabilities = [
                  "read"
                  "list"
                ];
              }
            ]
          ) p.kvReader
        );
        resolvedPkiRoles = lib.filter (e: e != null) (
          map (n: pkiRoleEntities.${n} or null) p.pkiIssuer
        );
        pkiIssueRules = map (e: {
          path = "${e.openbao-pki-role.mount}/issue/${e.openbao-pki-role.name}";
          capabilities = [ "update" ];
        }) resolvedPkiRoles;
        pkiMounts = lib.unique (map (e: e.openbao-pki-role.mount) resolvedPkiRoles);
        pkiCaRules = lib.flatten (map (m: [
          { path = "${m}/ca"; capabilities = [ "read" ]; }
          { path = "${m}/ca_chain"; capabilities = [ "read" ]; }
        ]) pkiMounts);
        resolvedSshRoles = lib.filter (e: e != null) (
          map (n: sshRoleEntities.${n} or null) p.sshSigner
        );
        sshSignerRules = map (e: {
          path = "${e.openbao-ssh-cert-role.mount}/sign/${e.openbao-ssh-cert-role.role}";
          capabilities = [ "update" ];
        }) resolvedSshRoles;
        effectiveRules =
          p.rules
          ++ kvReaderRules
          ++ pkiIssueRules
          ++ pkiCaRules
          ++ sshSignerRules;
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
      name: entity: egregore:
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
        assertion = egregore.entities ? ${sn} && egregore.entities.${sn}.kv-secret != null;
        message = "openbao-policy '${name}' kvReader '${sn}' is not a kv-secret entity";
      }) p.kvReader
      ++ map (rn: {
        assertion = egregore.entities ? ${rn} && egregore.entities.${rn}.openbao-pki-role != null;
        message = "openbao-policy '${name}' pkiIssuer '${rn}' is not an openbao-pki-role entity";
      }) p.pkiIssuer
      ++ map (rn: {
        assertion = egregore.entities ? ${rn} && egregore.entities.${rn}.openbao-ssh-cert-role != null;
        message = "openbao-policy '${name}' sshSigner '${rn}' is not an openbao-ssh-cert-role entity";
      }) p.sshSigner;
  };
}
