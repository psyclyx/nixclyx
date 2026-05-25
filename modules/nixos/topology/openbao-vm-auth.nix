# Egregore → OpenBao cert-auth wiring for microvm guests.
#
# Hypervisor side: for each guest where `host.openbao.cert.role` is
# set, emit a `openbao-wrap-<vm>.service` that mints a wrapped
# bootstrap token via the matching `<role>-init` token role; the
# token is written into a per-VM directory that microvm.shares
# virtiofs-mounts into the guest at /run/openbao-init.
#
# Guest side: if my own entity declares `host.openbao.cert.role`,
# enable `services.openbao-vm-auth` with the derived CN, PKI role,
# and OpenBao endpoint.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.nixos.topology.openbao-vm-auth;
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  enabled = cfg.enable && hostname != "";

  obo = eg.openbao or { };
  oboServerEnt = eg.entities.${obo.serverHost or ""} or null;
  oboServerAddr =
    if oboServerEnt == null then null
    else (oboServerEnt.attrs.addresses.${obo.serverNetwork or ""} or {}).ipv4 or null;
  derivedVaultAddr =
    if oboServerAddr == null then null
    else "${obo.scheme}://${oboServerAddr}:${toString obo.port}";

  me = eg.entities.${hostname} or null;

  # ─── Guest side ───────────────────────────────────────────────

  myCertBinding =
    if me == null then null
    else (me.host.openbao or { }).cert or null;

  guestCertRoleName = if myCertBinding == null then null else myCertBinding.role;
  guestCertRole =
    if guestCertRoleName == null then null
    else eg.entities.${guestCertRoleName} or null;

  guestCommonName =
    if myCertBinding == null then null
    else if myCertBinding.commonName != null then myCertBinding.commonName
    else (me.attrs.fqdns or { }).${myCertBinding.network} or null;

  # ─── Hypervisor side ──────────────────────────────────────────

  # Guests whose hypervisor is this host AND that have a cert binding.
  myGuestsWithCert = lib.filterAttrs (
    _: e:
    e.type == "host"
    && (e.refs.hypervisor or null) == hostname
    && (((e.host.openbao or { }).cert or null) != null)
  ) eg.entities;

  vmTokenRole =
    vm:
    let
      roleName = vm.host.openbao.cert.role;
      roleEnt = eg.entities.${roleName} or null;
    in
    if roleEnt == null then null else roleEnt.attrs.tokenRoleName;

  wrapTokenDir = vmName: "/var/lib/microvms/${vmName}/openbao-init";
  wrapTokenFile = vmName: "${wrapTokenDir vmName}/wrap-token";

  mkWrapUnit =
    vmName: vm:
    {
      description = "Mint OpenBao bootstrap wrap token for ${vmName}";
      after = [ "openbao-login.service" ];
      wants = [ "openbao-login.service" ];
      wantedBy = [ "microvms.target" ];
      before = [
        "microvms.target"
        "microvm@${vmName}.service"
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "30s";
      };
      environment = {
        BAO_ADDR = cfg.vaultAddr;
      } // lib.optionalAttrs cfg.insecureSkipVerify {
        VAULT_SKIP_VERIFY = "true";
      };
      path = [ pkgs.openbao pkgs.jq pkgs.bash pkgs.coreutils ];
      script = ''
        set -euo pipefail
        mkdir -p ${lib.escapeShellArg (wrapTokenDir vmName)}
        chmod 0700 ${lib.escapeShellArg (wrapTokenDir vmName)}

        if [ ! -s /run/openbao-auth/services-token ]; then
          echo "no openbao token — bailing (openbao-login likely failed)"
          exit 0
        fi
        BAO_TOKEN="$(cat /run/openbao-auth/services-token)"
        export BAO_TOKEN

        OUT=$(bao write -wrap-ttl=10m -force -format=json \
                auth/token/create/${lib.escapeShellArg (vmTokenRole vm)} || true)
        if [ -z "$OUT" ]; then
          echo "wrap token mint failed; keeping existing file if any"
          exit 0
        fi
        echo "$OUT" | jq -r '.wrap_info.token' \
          > ${lib.escapeShellArg (wrapTokenFile vmName)}.new
        chmod 0600 ${lib.escapeShellArg (wrapTokenFile vmName)}.new
        mv ${lib.escapeShellArg (wrapTokenFile vmName)}.new \
           ${lib.escapeShellArg (wrapTokenFile vmName)}
        echo "wrap token written for ${vmName}"
      '';
    };

  hypervisorEnabled = cfg.enable && myGuestsWithCert != { };
in
{
  options.psyclyx.nixos.topology.openbao-vm-auth = {
    enable = lib.mkEnableOption ''
      project host.openbao.cert bindings into hypervisor-side
      wrap-token minters and guest-side openbao-vm-auth services.
    '';

    vaultAddr = lib.mkOption {
      type = lib.types.str;
      default = if derivedVaultAddr != null then derivedVaultAddr else "";
      defaultText = lib.literalExpression ''
        "<scheme>://<addr>:<port>" derived from
        globals.openbao.{serverHost,serverNetwork,port,scheme}.
      '';
      description = ''
        OpenBao endpoint used by both the hypervisor's wrap-token
        minter and the guest's vm-auth. Default derived from egregore
        globals `openbao.*` — the host entity named by `serverHost`,
        its address on `serverNetwork`, and the configured port.
      '';
    };

    insecureSkipVerify = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Skip TLS verification when talking to OpenBao. Default true
        because the fleet OpenBao currently uses a self-signed
        listener cert (no CA distribution in place yet) and clients
        all sit on trusted VLANs. Flip to false once a CA is
        baked / fetched.
      '';
    };

    # Exposed for the microvm-vms projection to find per-VM wrap
    # token dirs so it can attach the virtiofs share.
    wrapTokenDirFor = lib.mkOption {
      type = lib.types.functionTo lib.types.str;
      default = wrapTokenDir;
      readOnly = true;
      internal = true;
    };
  };

  config = lib.mkIf enabled (lib.mkMerge [
    # Hypervisor side: per-guest wrap-token minter services + the
    # virtiofs share that hands the token to the guest.
    (lib.mkIf hypervisorEnabled {
      systemd.services = lib.mapAttrs' (
        vmName: vm: lib.nameValuePair "openbao-wrap-${vmName}" (mkWrapUnit vmName vm)
      ) myGuestsWithCert;
      systemd.tmpfiles.rules = lib.mapAttrsToList (
        vmName: _: "d ${wrapTokenDir vmName} 0700 root root - -"
      ) myGuestsWithCert;
      microvm.vms = lib.mapAttrs (vmName: _: {
        config.microvm.shares = [
          {
            tag = "openbao-init";
            proto = "virtiofs";
            source = wrapTokenDir vmName;
            mountPoint = "/run/openbao-init";
            securityModel = "passthrough";
          }
        ];
      }) myGuestsWithCert;
    })

    # Guest side: enable openbao-vm-auth with values from our
    # cert binding + the named cert-role entity.
    (lib.mkIf (myCertBinding != null && guestCertRole != null && guestCommonName != null) {
      psyclyx.nixos.services.openbao-vm-auth = {
        enable = true;
        vaultAddr = cfg.vaultAddr;
        insecureSkipVerify = cfg.insecureSkipVerify;
        pki.mount = guestCertRole.attrs.pkiMount;
        pki.role = guestCertRole.attrs.pkiRoleName;
        commonName = guestCommonName;
        ttl = guestCertRole.openbao-cert-role.leafTtl;
      };
    })
  ]);
}
