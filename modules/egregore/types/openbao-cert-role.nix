# Entity type: OpenBao cert auth role.
#
# A cert-auth role on the fleet OpenBao. Hosts that name this role
# via `host.openbao.cert.role` auth with a client cert signed by the
# fleet PKI; the role determines which policies they get (post-auth
# steady state) and how the bootstrap policy is named (used by the
# hypervisor's wrap-token minter for the first-cert handshake).
#
# Cross-entity refs (pkiRoleRef, policies, initPolicy) are *entity
# names*, not the eventual openbao-side names. The projection resolves
# them via attrs so changing what an openbao-pki-role / openbao-policy
# calls itself in OpenBao doesn't silently break this role.
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
    pkiRoleRef = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Name of the openbao-pki-role entity used to mint client
        certs for this group. Required (asserted). The projection
        resolves to the role's mount + openbao-side name; the cert
        role itself never spells out those strings.
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
      description = ''
        Names of openbao-policy entities granted to a successfully
        cert-authed client. Refs are by entity name; the projection
        resolves to each policy's openbao-side name.
      '';
    };
    initPolicy = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Name of the openbao-policy entity attached to the wrapped
        bootstrap token. That policy must permit minting from the
        configured pkiRoleRef so the new VM can mint its first cert.
        Required (asserted).
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
    name: entity: top:
    let
      r = entity.openbao-cert-role;
      pkiRoleEnt = top.entities.${r.pkiRoleRef} or null;
      policyEnts = lib.filter (e: e != null) (
        map (n: top.entities.${n} or null) r.policies
      );
      initPolicyEnt = top.entities.${r.initPolicy} or null;
    in
    {
      label = r.name;
      tokenRoleName = "${r.name}-init";
      pkiMount = if pkiRoleEnt == null then null else pkiRoleEnt.openbao-pki-role.mount;
      pkiRoleName = if pkiRoleEnt == null then null else pkiRoleEnt.openbao-pki-role.name;
      policyNames = map (e: e.openbao-policy.name) policyEnts;
      initPolicyName = if initPolicyEnt == null then null else initPolicyEnt.openbao-policy.name;
    };

  assertions =
    name: entity: top:
    let
      r = entity.openbao-cert-role;
    in
    [
      {
        assertion = r.name != "";
        message = "openbao-cert-role '${name}' requires a non-empty name";
      }
      {
        assertion = r.pkiRoleRef != "";
        message = "openbao-cert-role '${name}' requires pkiRoleRef (an openbao-pki-role entity name)";
      }
      {
        assertion =
          r.pkiRoleRef == ""
          || (top.entities ? ${r.pkiRoleRef} && top.entities.${r.pkiRoleRef}.type == "openbao-pki-role");
        message = "openbao-cert-role '${name}' pkiRoleRef '${r.pkiRoleRef}' is not an openbao-pki-role entity";
      }
      {
        assertion = r.initPolicy != "";
        message = "openbao-cert-role '${name}' requires initPolicy (an openbao-policy entity name)";
      }
      {
        assertion =
          r.initPolicy == ""
          || (top.entities ? ${r.initPolicy} && top.entities.${r.initPolicy}.type == "openbao-policy");
        message = "openbao-cert-role '${name}' initPolicy '${r.initPolicy}' is not an openbao-policy entity";
      }
      {
        assertion = r.policies != [ ];
        message = "openbao-cert-role '${name}' requires at least one steady-state policy";
      }
    ]
    ++ map (pn: {
      assertion = top.entities ? ${pn} && top.entities.${pn}.type == "openbao-policy";
      message = "openbao-cert-role '${name}' policies '${pn}' is not an openbao-policy entity";
    }) r.policies;
}
