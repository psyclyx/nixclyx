# Entity type: OpenBao seal oracle.
#
# An openbao instance whose unsealing is delegated to a TPM-backed key
# (refs.tpmKey). The bootstrap projection wires up first-boot init
# capture: on the first run where the server is reachable but
# uninitialized, the projection's one-shot runs `bao operator init`
# and writes the recovery secrets to a path for the orchestrator to
# capture into sops at refs.initSecretsSops.
#
# The seal-oracle entity is intentionally distinct from any
# openbao-server entity that might run alongside it: an oracle's
# whole job is to broker the seal; an openbao-server may use the
# oracle as a transit seal and have its own init lifecycle.
{
  lib,
  egregorLib,
  config,
  ...
}:
egregorLib.mkType {
  name = "openbao-seal-oracle";
  topConfig = config;
  description = "An openbao instance sealed by a TPM-backed key, with first-boot init capture.";

  options = {
    address = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        Address (BAO_ADDR) clients use to reach this seal oracle's
        API. Required (asserted non-empty); empty default keeps non-
        oracle entities clean.
      '';
    };
    initSecretsPath = lib.mkOption {
      type = lib.types.str;
      default = "/run/openbao-init-secrets";
      description = ''
        Producer-side path where the init one-shot writes the JSON
        from `bao operator init`. Lives in /run on purpose so the file
        vanishes on reboot, forcing the operator to capture promptly.
      '';
    };
    initSentinel = lib.mkOption {
      type = lib.types.str;
      default = "/persist/.openbao-initialized";
      description = ''
        Sentinel file marking that init has already run. Lives in
        /persist so it survives reboots. The one-shot is gated on
        this file's absence.
      '';
    };
    recoveryShares = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Number of recovery key shares to generate at init.";
    };
    recoveryThreshold = lib.mkOption {
      type = lib.types.int;
      default = 1;
      description = "Recovery threshold (must be ≤ recoveryShares).";
    };
  };

  attrs =
    name: entity: _top:
    let
      o = entity.openbao-seal-oracle;
    in
    {
      label = "${o.address} (seal: ${entity.refs.tpmKey or "<?>"})";
      producer = entity.refs.host or null;
    };

  assertions =
    name: entity: top:
    let
      o = entity.openbao-seal-oracle;
      host = entity.refs.host or null;
      tpmKey = entity.refs.tpmKey or null;
    in
    [
      {
        assertion = o.address != "";
        message = "openbao-seal-oracle '${name}' requires a non-empty address";
      }
      {
        assertion = host != null;
        message = "openbao-seal-oracle '${name}' requires refs.host";
      }
      {
        assertion = host == null || (top.entities ? ${host} && top.entities.${host}.type == "host");
        message = "openbao-seal-oracle '${name}' refs.host '${toString host}' must be a host entity";
      }
      {
        assertion = tpmKey != null;
        message = "openbao-seal-oracle '${name}' requires refs.tpmKey";
      }
      {
        assertion = tpmKey == null || (top.entities ? ${tpmKey} && top.entities.${tpmKey}.type == "tpm-key");
        message = "openbao-seal-oracle '${name}' refs.tpmKey '${toString tpmKey}' must be a tpm-key entity";
      }
      {
        assertion = tpmKey == null || host == null
          || (top.entities.${tpmKey}.refs.host or null) == host;
        message = "openbao-seal-oracle '${name}' tpmKey '${toString tpmKey}' lives on a different host than the oracle";
      }
      {
        assertion = o.recoveryThreshold >= 1 && o.recoveryThreshold <= o.recoveryShares;
        message = "openbao-seal-oracle '${name}' recoveryThreshold out of range";
      }
    ];
}
