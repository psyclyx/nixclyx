# Entity type: OpenBao SSH cert-signing role.
#
# Combines a mount path (where the SSH secrets engine + its CA live)
# with a role on that mount. The fleet projection enables the
# engine, generates the CA signing key, and writes the role.
#
# Two roles are typical:
#   - kind = "host": signs SSH host pubkeys. allowedDomains + allow
#     subdomains constrain which CNs can be issued; the VM consumes
#     via its cert-auth token to sign its own host key on boot.
#   - kind = "user": signs SSH user pubkeys. allowedUsers limits the
#     principals you can request. Operators authenticate (e.g. via
#     userpass) and sign their pubkey to get a session cert.
#
# One mount = one CA. Use different mounts for host vs user CAs so
# host-key compromise can't issue user certs (and vice versa).
{
  lib,
  egregorLib,
  config,
  ...
}:
egregorLib.mkType {
  name = "openbao-ssh-cert-role";
  topConfig = config;
  description = "An OpenBao SSH role for host- or user-cert signing.";

  options = {
    mount = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        SSH secrets engine mount path. Required (asserted). Each
        mount has its own CA; the projection enables the engine +
        generates a signing key on first deploy.
      '';
    };
    role = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Role name (under the mount). Required (asserted).
      '';
    };
    kind = lib.mkOption {
      type = lib.types.nullOr (lib.types.enum [ "host" "user" ]);
      default = null;
      description = ''
        Whether this role signs host pubkeys or user pubkeys.
        Required for real entries (asserted non-null); the null
        default exists so non-ssh-cert-role entities don't trip the
        option-without-default check.
      '';
    };
    keyType = lib.mkOption {
      type = lib.types.str;
      default = "ed25519";
      description = "Signing key algorithm for the CA (ed25519/ec/rsa).";
    };
    allowedDomains = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        For kind = "host": domain suffixes whose CNs can be signed.
        E.g. ["lab.apt.psyclyx.net"] with allowSubdomains accepts
        ab-api.lab.apt.psyclyx.net.
      '';
    };
    allowSubdomains = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Permit subdomains under each allowedDomain.";
    };
    allowedUsers = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        For kind = "user": principals (login users) that may appear
        in the cert's valid_principals. Empty means no constraint —
        not recommended.
      '';
    };
    defaultUser = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        For kind = "user": default principal if the signing request
        doesn't specify one.
      '';
    };
    ttl = lib.mkOption {
      type = lib.types.str;
      default = "720h";
      description = "Default issued-cert TTL.";
    };
    maxTtl = lib.mkOption {
      type = lib.types.str;
      default = "720h";
      description = "Max issued-cert TTL.";
    };
    keyIdFormat = lib.mkOption {
      type = lib.types.str;
      default = "{{token_display_name}}";
      description = "OpenBao key_id_format template for the cert's KeyID field.";
    };
  };

  attrs =
    name: entity: _top:
    let
      r = entity.openbao-ssh-cert-role;
    in
    {
      label = "${r.mount}/${r.role} (${r.kind})";
      signPath = "${r.mount}/sign/${r.role}";
      caPubPath = "${r.mount}/public_key";
    };

  assertions =
    name: entity: _top:
    let
      r = entity.openbao-ssh-cert-role;
    in
    [
      {
        assertion = r.mount != "";
        message = "openbao-ssh-cert-role '${name}' requires a non-empty mount";
      }
      {
        assertion = r.role != "";
        message = "openbao-ssh-cert-role '${name}' requires a non-empty role";
      }
      {
        assertion = r.kind != null;
        message = "openbao-ssh-cert-role '${name}' requires kind (host|user)";
      }
      {
        assertion = r.kind != "host" || r.allowedDomains != [ ];
        message = "openbao-ssh-cert-role '${name}' has kind=host but no allowedDomains";
      }
    ];
}
