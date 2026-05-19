# Egregore → OpenBao server configuration projection.
#
# Runs on hosts whose `openbao-seal-oracle` runs the fleet OpenBao
# (detected via the seal-oracle being enabled). Reads the four
# OpenBao-shaped entity types and appends bao CLI commands to the
# seal-oracle's configure hook:
#
#   - openbao-policy        → `bao policy write`
#   - openbao-cert-role     → `bao auth/cert/certs/<name>` + paired
#                             `auth/token/roles/<name>-init`
#   - kv-secret             → `bao kv put` (value read from the
#                             producer's sops file path declared on
#                             the entity)
#
# Static prerequisites (KV engine, cert auth method, userpass) are
# left to whatever the host's own openbao-seal-oracle.configure
# block sets up. The projection only appends; it doesn't override.
{
  config,
  lib,
  ...
}:
let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  oboCfg = config.psyclyx.nixos.services.openbao-seal-oracle or { };
  enabled = (oboCfg.enable or false) && hostname != "";

  hostEntity = eg.entities.${hostname} or null;
  hostHere = hostEntity != null;

  policyEntities = lib.filterAttrs (_: e: e.type == "openbao-policy") eg.entities;
  pkiRoleEntities = lib.filterAttrs (_: e: e.type == "openbao-pki-role") eg.entities;
  certRoleEntities = lib.filterAttrs (_: e: e.type == "openbao-cert-role") eg.entities;
  kvSecretEntities = lib.filterAttrs (
    _: e: e.type == "kv-secret" && (e.refs.producer or null) == hostname && e.kv-secret.sourceFile != null
  ) eg.entities;

  mkPolicyBlock =
    _: p:
    let
      hcl = p.attrs.hcl;
    in
    ''
      bao policy write ${lib.escapeShellArg p.openbao-policy.name} - <<'EOF'
      ${hcl}
      EOF
    '';

  mkPkiRoleBlock =
    _: r:
    let
      pr = r.openbao-pki-role;
    in
    ''
      bao write ${lib.escapeShellArg pr.mount}/roles/${lib.escapeShellArg pr.name} \
        allowed_domains=${lib.escapeShellArg (lib.concatStringsSep "," pr.allowedDomains)} \
        allow_subdomains=${lib.boolToString pr.allowSubdomains} \
        allow_ip_sans=${lib.boolToString pr.allowIpSans} \
        client_flag=${lib.boolToString pr.clientFlag} \
        server_flag=${lib.boolToString pr.serverFlag} \
        max_ttl=${lib.escapeShellArg pr.maxTtl}
    '';

  mkCertRoleBlock =
    _: r:
    let
      cr = r.openbao-cert-role;
    in
    ''
      # cert auth role: ${cr.name}
      CA_PEM=$(bao read -field=certificate ${lib.escapeShellArg cr.pkiMount}/cert/ca)
      bao write auth/cert/certs/${lib.escapeShellArg cr.name} \
        display_name=${lib.escapeShellArg cr.name} \
        token_policies=${lib.escapeShellArg (lib.concatStringsSep "," cr.policies)} \
        ${lib.optionalString (cr.boundCidrs != [ ]) ''
          token_bound_cidrs=${lib.escapeShellArg (lib.concatStringsSep "," cr.boundCidrs)} \
        ''}\
        allowed_common_names_glob=${lib.escapeShellArg cr.cnGlob} \
        certificate=-<<<"$CA_PEM"

      # paired bootstrap token role: ${r.attrs.tokenRoleName}
      bao write auth/token/roles/${lib.escapeShellArg r.attrs.tokenRoleName} \
        allowed_policies=${lib.escapeShellArg cr.initPolicy} \
        orphan=true \
        token_explicit_max_ttl=${toString cr.bootstrapTtl}
    '';

  mkKvSecretBlock =
    _: s:
    let
      sf = s.kv-secret;
    in
    ''
      VAL=$(cat ${lib.escapeShellArg sf.sourceFile})
      bao kv put ${lib.escapeShellArg sf.mount}/${lib.escapeShellArg sf.path} \
        ${lib.escapeShellArg sf.valueField}="$VAL"
    '';

  configureExtra =
    lib.concatStrings (lib.mapAttrsToList mkPolicyBlock policyEntities)
    + lib.concatStrings (lib.mapAttrsToList mkPkiRoleBlock pkiRoleEntities)
    + lib.concatStrings (lib.mapAttrsToList mkCertRoleBlock certRoleEntities)
    + lib.concatStrings (lib.mapAttrsToList mkKvSecretBlock kvSecretEntities);
in
{
  options.psyclyx.nixos.topology.openbao-fleet = {
    enable = lib.mkEnableOption ''
      project openbao-policy, openbao-cert-role, and kv-secret
      entities into the local openbao-seal-oracle's configure hook.
      Only runs on hosts that actually run the fleet OpenBao.
    '';
  };

  config = lib.mkIf (enabled && config.psyclyx.nixos.topology.openbao-fleet.enable && hostHere) {
    psyclyx.nixos.services.openbao-seal-oracle.configure = lib.mkAfter configureExtra;
  };
}
