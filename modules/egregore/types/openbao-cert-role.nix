# Entity type: OpenBao cert auth role.
#
# A cert-auth role on the fleet OpenBao. Hosts that name this role
# via `host.openbao.cert.role` auth with a client cert signed by the
# fleet PKI; the role determines which policies they get (post-auth
# steady state) and how the bootstrap policy is named (used by the
# hypervisor's wrap-token minter for the first-cert handshake).
{
  lib,
  egregorLib,
  config,
  ...
}:
egregorLib.mkType {
  name = "openbao-cert-role";
  topConfig = config;
  description = "An OpenBao cert auth role + paired bootstrap token role.";

  options = {
    name = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Role name. Used as both the cert auth role name and the
        prefix for the paired bootstrap token role
        (`<name>-init`). Required for real entries (asserted).
      '';
    };
    pkiMount = lib.mkOption {
      type = lib.types.str;
      default = "pki";
      description = "PKI mount on OpenBao whose root signs these certs.";
    };
    pkiRole = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        PKI role used to mint client certs for this group. Required
        (asserted). The role's allowed_domains + allow_subdomains
        determine which CNs are accepted; for `<host>.<network>.<site>.<domain>`
        names the allowed_domains is typically the site or
        network zone.
      '';
    };
    boundCidrs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        CIDR ranges (from OpenBao's perspective) that are allowed to
        present a cert under this role. Empty means no IP restriction.
      '';
    };
    cnGlob = lib.mkOption {
      type = lib.types.str;
      default = "*";
      description = "Glob applied to the cert's CN at auth time.";
    };
    policies = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Policies granted to a successfully cert-authed client.";
    };
    initPolicy = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Policy attached to the wrapped bootstrap token. Must permit
        `update pki/issue/<pkiRole>` so the new VM can mint its
        first cert. Required (asserted).
      '';
    };
    bootstrapTtl = lib.mkOption {
      type = lib.types.int;
      default = 600;
      description = "Max TTL (seconds) of the bootstrap token.";
    };
    leafTtl = lib.mkOption {
      type = lib.types.str;
      default = "720h";
      description = "TTL requested for issued client certs.";
    };
  };

  attrs =
    name: entity: _top:
    let
      r = entity.openbao-cert-role;
    in
    {
      label = r.name;
      tokenRoleName = "${r.name}-init";
    };

  assertions =
    name: entity: _top:
    let
      r = entity.openbao-cert-role;
    in
    [
      {
        assertion = r.name != "";
        message = "openbao-cert-role '${name}' requires a non-empty name";
      }
      {
        assertion = r.pkiRole != "";
        message = "openbao-cert-role '${name}' requires pkiRole";
      }
      {
        assertion = r.initPolicy != "";
        message = "openbao-cert-role '${name}' requires initPolicy";
      }
      {
        assertion = r.policies != [ ];
        message = "openbao-cert-role '${name}' requires at least one steady-state policy";
      }
    ];
}
