# MIT Kerberos KDC (key distribution center).
#
# Declarative end-to-end. No manual rituals:
#  - DB + stash created at activation from a sops-managed master
#    password (idempotent — only runs if the DB doesn't exist).
#  - Principal list comes from `principals` (driven by egregore via
#    derived/kerberos.nix). The provisioning service ensures every
#    listed principal exists in the KDC DB and pushes its keytab
#    base64-encoded to OpenBao KV.
#  - Disk loss = redeploy → DB regenerates, keys rotate, keytabs
#    refresh in OpenBao, clients re-pull. No human steps.
{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "kerberos-kdc"
  ];
  description = "MIT Kerberos KDC server (declarative)";

  options =
    { lib, ... }:
    {
      enable = lib.mkEnableOption "MIT Kerberos KDC";

      realm = lib.mkOption {
        type = lib.types.str;
        description = "Realm name (e.g. PSYCLYX.NET).";
      };

      role = lib.mkOption {
        type = lib.types.enum [
          "primary"
          "secondary"
        ];
        default = "primary";
        description = ''
          KDC role. `primary` owns the canonical DB, runs kadmind and
          principal provisioning, pushes via kprop to secondaries.
          `secondary` runs kpropd to receive DB pushes; no direct
          writes.
        '';
      };

      masterPasswordFile = lib.mkOption {
        type = lib.types.path;
        description = ''
          Path to a sops-managed file containing the realm's master
          password. Used by `kdb5_util create -s -P` at first
          activation to deterministically derive the stash file +
          encrypt the DB. Same password produces the same stash, so
          a redeploy onto a fresh disk regenerates a compatible KDC
          (modulo principal data, which the provisioning step
          repopulates).
        '';
      };

      principals = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Principals to ensure exist in the KDC DB (primary only).
          Each entry is a full principal string (`host/foo@REALM`,
          `nfs/lab-4.apt.psyclyx.net@REALM`). The provisioning
          activation service uses `kadmin.local addprinc -randkey`
          to mint any principal missing from the DB, then exports
          its keytab and pushes the base64-encoded form to OpenBao
          KV under `<keytabKvMount>/<keytabKvPrefix>/<safe-name>`
          (where safe-name is the principal with /+@ replaced by _).
        '';
      };

      keytabKvMount = lib.mkOption {
        type = lib.types.str;
        default = "kv";
        description = "OpenBao KV v2 mount where keytabs are stored.";
      };

      keytabKvPrefix = lib.mkOption {
        type = lib.types.str;
        default = "keytabs";
        description = "KV path prefix below the mount for keytabs.";
      };

      openbao = lib.mkOption {
        type = lib.types.submodule {
          options = {
            vaultAddr = lib.mkOption { type = lib.types.str; };
            tokenFile = lib.mkOption {
              type = lib.types.str;
              default = "/run/openbao-auth/services-token";
            };
            insecureSkipVerify = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
          };
        };
        description = ''
          OpenBao endpoint config used by the principal-provisioning
          service to push keytabs. Should match the host's existing
          openbao-login output.
        '';
      };

      secondaries = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Hostnames/addresses of secondary KDCs to kprop-push the DB
          to (primary only). Empty = no replication.
        '';
      };

      acl = lib.mkOption {
        type = lib.types.listOf (
          lib.types.submodule {
            options = {
              principal = lib.mkOption { type = lib.types.str; };
              access = lib.mkOption {
                type = lib.types.listOf (lib.types.enum [
                  "add" "cpw" "delete" "get" "get-keys" "list" "modify" "all"
                ]);
              };
              target = lib.mkOption {
                type = lib.types.str;
                default = "*";
              };
            };
          }
        );
        default = [
          { principal = "*/admin@PSYCLYX.NET"; access = [ "all" ]; target = "*"; }
        ];
        description = "kadmin ACL — who can perform what against which principals.";
      };
    };

  config =
    {
      cfg,
      config,
      lib,
      pkgs,
      ...
    }:
    let
      krb5 = pkgs.krb5;
      jq = "${pkgs.jq}/bin/jq";
      bao = "${pkgs.openbao}/bin/bao";

      # Principal-name-safe encoding for KV paths.
      safeName = p:
        let
          # Replace '/' and '@' with '_'.
          replaced = builtins.replaceStrings [ "/" "@" ] [ "_" "_" ] p;
        in replaced;

      provisionScript = ''
        set -euo pipefail
        if [ ! -f ${lib.escapeShellArg cfg.openbao.tokenFile} ]; then
          echo "OpenBao token file missing; skipping principal provisioning"
          exit 0
        fi
        export BAO_ADDR=${lib.escapeShellArg cfg.openbao.vaultAddr}
        export BAO_TOKEN="$(cat ${lib.escapeShellArg cfg.openbao.tokenFile})"
        ${lib.optionalString cfg.openbao.insecureSkipVerify "export VAULT_SKIP_VERIFY=true"}

        umask 077

        ${lib.concatMapStringsSep "\n" (p: ''
          PRINC=${lib.escapeShellArg p}
          KV_KEY=${lib.escapeShellArg (safeName p)}

          # Check if principal exists. kadmin.local exits non-zero on
          # missing; capture stderr to suppress noise.
          if ${krb5}/bin/kadmin.local -q "getprinc $PRINC" 2>/dev/null \
              | grep -q "^Principal:"; then
            echo "Principal $PRINC already exists, skipping"
          else
            echo "Creating principal $PRINC"
            ${krb5}/bin/kadmin.local -q "addprinc -randkey $PRINC"
          fi

          # (Re-)export the keytab and push to OpenBao. We do this every
          # run so clients can recover after a rotation. kadmin.local's
          # `ktadd` requires the target file to either not exist or be
          # an initialized keytab — passing an empty mktemp file fails
          # with "Unsupported key table format", so we mint a unique
          # name with mktemp -u and let ktadd create it.
          KT=$(mktemp -u -t kt.XXXXXX)
          ${krb5}/bin/kadmin.local -q "ktadd -norandkey -k $KT $PRINC" >/dev/null
          if [ ! -s "$KT" ]; then
            echo "ktadd produced no keytab for $PRINC; skipping" >&2
            continue
          fi
          B64=$(base64 -w 0 < "$KT")
          ${bao} kv put \
            -mount=${lib.escapeShellArg cfg.keytabKvMount} \
            ${lib.escapeShellArg "${cfg.keytabKvPrefix}/${safeName p}"} \
            "keytab=$B64" \
            "principal=$PRINC" >/dev/null
          shred -u "$KT"
        '') cfg.principals}
      '';
    in
    lib.mkIf cfg.enable {
      services.kerberos_server = {
        enable = true;
        settings.realms.${cfg.realm}.acl = cfg.acl;
      };

      # Idempotent DB bootstrap. The stash is derived from the master
      # password; same input → same key → existing DB stays openable.
      systemd.services.krb5kdc-init = {
        description = "Initialize KDC DB if missing";
        wantedBy = [ "kerberos-server.target" ];
        before = [ "kdc.service" "kadmind.service" ];
        after = [ "sops-install-secrets.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ krb5 ];
        script = ''
          set -euo pipefail
          mkdir -p /var/lib/krb5kdc
          chmod 700 /var/lib/krb5kdc
          if [ ! -f /var/lib/krb5kdc/principal ]; then
            echo "Initializing Kerberos DB for realm ${cfg.realm}..."
            PW=$(cat ${lib.escapeShellArg cfg.masterPasswordFile})
            kdb5_util -r ${lib.escapeShellArg cfg.realm} create -s -P "$PW"
            echo "Done."
          else
            echo "KDC DB already initialized; skipping."
          fi
        '';
      };

      # Principal provisioning: ensure every listed principal exists,
      # push its keytab to OpenBao. Primary only.
      systemd.services.krb5kdc-provision = lib.mkIf
        (cfg.role == "primary" && cfg.principals != [])
        {
          description = "Provision Kerberos principals + push keytabs to OpenBao";
          after = [
            "kdc.service"
            "kadmind.service"
            "openbao-login.service"
          ];
          wants = [ "openbao-login.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          path = [ krb5 pkgs.openbao pkgs.coreutils pkgs.jq ];
          script = provisionScript;
        };

      # Kprop replication push (primary → secondaries). Periodic.
      systemd.services.krb5kdc-replicate = lib.mkIf
        (cfg.role == "primary" && cfg.secondaries != [])
        {
          description = "Push KDC DB to secondaries via kprop";
          after = [ "kdc.service" ];
          path = [ krb5 ];
          serviceConfig.Type = "oneshot";
          script = ''
            set -euo pipefail
            DUMP=/var/lib/krb5kdc/dump
            kdb5_util dump "$DUMP"
            ${lib.concatMapStringsSep "\n" (peer: ''
              echo "Pushing to ${peer}..."
              kprop -f "$DUMP" ${lib.escapeShellArg peer}
            '') cfg.secondaries}
          '';
        };

      systemd.timers.krb5kdc-replicate = lib.mkIf
        (cfg.role == "primary" && cfg.secondaries != [])
        {
          description = "Periodic KDC DB replication";
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5m";
            OnUnitActiveSec = "15m";
          };
        };

      # Secondary: run kpropd to receive replicated DB.
      systemd.services.kpropd = lib.mkIf (cfg.role == "secondary") {
        description = "Kerberos KDC replication receiver";
        wantedBy = [ "kerberos-server.target" ];
        after = [ "krb5kdc-init.service" ];
        path = [ krb5 ];
        serviceConfig = {
          ExecStart = "${krb5}/bin/kpropd -S";
          Type = "simple";
          Restart = "always";
        };
      };

      # Disable kadmind on secondaries.
      systemd.services.kadmind.enable = cfg.role == "primary";

      networking.firewall.allowedTCPPorts =
        [ 88 464 ]
        ++ lib.optional (cfg.role == "primary") 749       # kadmin
        ++ lib.optional (cfg.role == "secondary") 754;    # kprop receiver
      networking.firewall.allowedUDPPorts = [ 88 464 ];

      environment.systemPackages = [ krb5 ];
    };
}
