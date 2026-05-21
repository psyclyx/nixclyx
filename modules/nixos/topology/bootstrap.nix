# Egregore → first-boot bootstrap projection.
#
# Turns entities that need attended-once setup into sentinel-gated
# systemd one-shots on the producer host. Currently covers:
#
#   - openbao-seal-oracle  →  openbao-init-<name>.service
#       Runs `bao operator init` if not yet initialized; writes the
#       JSON output to the entity's initSecretsPath (in /run, so it
#       vanishes on reboot and the operator must capture it). Creates
#       the sentinel and exits clean if openbao is already initialized
#       — safe to enable on a host that's been hand-initialized.
#
# Each first-boot service is gated on a /persist sentinel so it runs
# exactly once across reboots. The actual capture of the init secrets
# (encrypting into sops, committing) is operator-driven — see
# scripts/bootstrap-host.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.psyclyx.nixos.topology.bootstrap;
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;
  enabled = cfg.enable && hostname != "";

  oracles = lib.filterAttrs (_: e:
    e.type == "openbao-seal-oracle"
    && (e.refs.host or null) == hostname
  ) eg.entities;

  mkOpenbaoInitService =
    name: oracle:
    let
      o = oracle.openbao-seal-oracle;
    in
    lib.nameValuePair "openbao-init-${name}" {
      description = "Capture openbao init secrets for ${name}";
      wantedBy = [ "multi-user.target" ];
      after = [ "openbao-seal-oracle.service" "openbao.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      unitConfig.ConditionPathExists = "!${o.initSentinel}";
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        TimeoutStartSec = "5min";
      };
      environment = {
        BAO_ADDR = o.address;
        VAULT_SKIP_VERIFY = "true";  # self-signed listener — flip when CA is in place
      };
      path = [ pkgs.openbao pkgs.jq pkgs.coreutils pkgs.bash ];
      script = ''
        set -euo pipefail
        mkdir -p $(dirname ${lib.escapeShellArg o.initSentinel})

        # Wait until openbao is reachable. Up to ~2min then bail.
        for i in $(seq 1 60); do
          if bao status -format=json >/dev/null 2>&1; then break; fi
          sleep 2
        done

        if bao status -format=json | jq -e '.initialized' >/dev/null; then
          echo "openbao at ${o.address} already initialized; creating sentinel"
          touch ${lib.escapeShellArg o.initSentinel}
          exit 0
        fi

        umask 077
        bao operator init \
          -recovery-shares=${toString o.recoveryShares} \
          -recovery-threshold=${toString o.recoveryThreshold} \
          -format=json > ${lib.escapeShellArg o.initSecretsPath}.tmp
        mv ${lib.escapeShellArg o.initSecretsPath}.tmp ${lib.escapeShellArg o.initSecretsPath}
        chmod 0600 ${lib.escapeShellArg o.initSecretsPath}
        touch ${lib.escapeShellArg o.initSentinel}

        cat <<EOF >&2
        ===========================================================
        BOOTSTRAP: openbao at ${o.address} initialized. Capture
        the secrets in ${o.initSecretsPath} immediately — the file
        lives on tmpfs and vanishes on reboot. From sigil:

          ./scripts/bootstrap-host ${hostname} --capture-openbao-init

        ===========================================================
        EOF
      '';
    };

  oracleServices = lib.mapAttrs' mkOpenbaoInitService oracles;
in
{
  options.psyclyx.nixos.topology.bootstrap = {
    enable = lib.mkEnableOption ''
      project first-boot bootstrap entities (openbao-seal-oracle init,
      future: tpm-key provision, clevis-binding first-time bind) into
      sentinel-gated systemd one-shots on the producer host.
    '';
  };

  config = lib.mkIf enabled {
    systemd.services = oracleServices;
  };
}
