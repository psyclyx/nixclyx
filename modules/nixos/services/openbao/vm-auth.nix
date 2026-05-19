# OpenBao cert-auth for microvm guests.
#
# Two concerns in one unit:
#   1. **Bootstrap** — on first boot (or when the cert is gone /
#      near-expiry), unwrap a one-time wrap token shared in by the
#      hypervisor, mint a client cert via the configured PKI role,
#      and store it in the VM's persistent state directory.
#   2. **Login** — auth to OpenBao with the persisted cert and write
#      the resulting service token to /run/openbao-auth/services-token
#      so downstream `openbao-kv` consumers can fetch secrets.
#
# Lives in nixclyx (fleet-agnostic). The privclyx-layer lab-4 config
# is what mints the wrap tokens; this module on the guest side just
# expects the token file to be present when no cert exists yet.
{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "openbao-vm-auth"
  ];
  description = "OpenBao bootstrap + cert auth for microvm guests";

  options =
    { lib, ... }:
    {
      enable = lib.mkEnableOption "OpenBao cert-auth lifecycle for this guest";

      vaultAddr = lib.mkOption {
        type = lib.types.str;
        description = "OpenBao API endpoint reachable from the guest.";
        example = "http://10.0.25.1:8200";
      };

      stateDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/openbao-auth";
        description = ''
          Persistent directory holding the cert, key, and CA. Must
          survive reboots — point at a mountpoint backed by a LUN.
        '';
      };

      tokenFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/openbao-auth/services-token";
        description = "Path to write the issued service token for openbao-kv consumers.";
      };

      pki.mount = lib.mkOption {
        type = lib.types.str;
        default = "pki";
        description = "PKI engine mount path on the OpenBao server.";
      };

      pki.role = lib.mkOption {
        type = lib.types.str;
        description = "PKI role used for both bootstrap and renewal.";
        example = "angelbeats-vm";
      };

      commonName = lib.mkOption {
        type = lib.types.str;
        description = "Subject CN requested from PKI. Must match the cert auth method's allowed_common_names_glob.";
        example = "ab-api.angelbeats.internal";
      };

      ttl = lib.mkOption {
        type = lib.types.str;
        default = "720h";
        description = "Requested cert lifetime (PKI role enforces its own max).";
      };

      renewMargin = lib.mkOption {
        type = lib.types.str;
        default = "168h";
        description = "Refresh the cert when its remaining TTL drops below this.";
      };

      wrapTokenFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/openbao-init/wrap-token";
        description = ''
          File holding the one-time wrap token the hypervisor placed
          here via virtiofs share. Consumed (and the file ignored
          thereafter) on first cert mint; not needed for renewal.
        '';
      };
    };

  config =
    {
      cfg,
      lib,
      pkgs,
      ...
    }:
    lib.mkIf cfg.enable {
      systemd.services.openbao-vm-auth = {
        description = "OpenBao cert lifecycle (${cfg.commonName} → ${cfg.vaultAddr})";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        # Retry hourly so an unreachable OpenBao at boot self-heals
        # later. The renew margin keeps the cert from drifting close
        # to expiry between retries.
        startAt = "hourly";

        environment = {
          BAO_ADDR = cfg.vaultAddr;
          HOME = "/run/openbao-auth";
          VAULT_CLIENT_TIMEOUT = "5";
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "openbao-auth";
          RuntimeDirectoryMode = "0700";
          StateDirectory = lib.removePrefix "/var/lib/" cfg.stateDir;
          StateDirectoryMode = "0700";
          TimeoutStartSec = "120s";
        };

        path = [
          pkgs.openbao
          pkgs.jq
          pkgs.openssl
          pkgs.bash
          pkgs.coreutils
        ];

        script = ''
          set -euo pipefail
          umask 077

          CERT=${lib.escapeShellArg cfg.stateDir}/cert.pem
          KEY=${lib.escapeShellArg cfg.stateDir}/key.pem
          CA=${lib.escapeShellArg cfg.stateDir}/ca.pem

          # Helper: is the existing cert valid and not within the
          # renewal margin? Returns 0 if we can skip the mint.
          cert_fresh() {
            [ -s "$CERT" ] || return 1
            # `openssl x509 -checkend N` returns 0 iff cert is NOT
            # expiring within N seconds.
            local margin_sec
            case "${cfg.renewMargin}" in
              *h) margin_sec=$(( ''${cfg.renewMargin%h} * 3600 )) ;;
              *m) margin_sec=$(( ''${cfg.renewMargin%m} * 60 )) ;;
              *s) margin_sec=$(( ''${cfg.renewMargin%s} )) ;;
              *)  margin_sec=604800 ;;
            esac
            openssl x509 -checkend "$margin_sec" -noout -in "$CERT" >/dev/null 2>&1
          }

          # If we don't have a cert yet, bootstrap via the wrap token.
          if [ ! -s "$CERT" ]; then
            if [ ! -s ${lib.escapeShellArg cfg.wrapTokenFile} ]; then
              echo "no cert and no wrap token at ${cfg.wrapTokenFile} — cannot bootstrap"
              exit 1
            fi

            echo "bootstrapping cert via wrap token"
            WRAP=$(cat ${lib.escapeShellArg cfg.wrapTokenFile})

            UNWRAPPED=$(BAO_TOKEN="$WRAP" bao unwrap -format=json)
            BOOTSTRAP_TOKEN=$(echo "$UNWRAPPED" | jq -r '.auth.client_token')

            # Mint cert. PKI returns cert, private key, CA chain.
            ISSUE=$(BAO_TOKEN="$BOOTSTRAP_TOKEN" \
              bao write -format=json \
                ${lib.escapeShellArg cfg.pki.mount}/issue/${lib.escapeShellArg cfg.pki.role} \
                common_name=${lib.escapeShellArg cfg.commonName} \
                ttl=${lib.escapeShellArg cfg.ttl})

            echo "$ISSUE" | jq -r '.data.certificate'   > "$CERT".new
            echo "$ISSUE" | jq -r '.data.private_key'   > "$KEY".new
            echo "$ISSUE" | jq -r '.data.issuing_ca'    > "$CA".new
            chmod 0400 "$CERT".new "$KEY".new "$CA".new
            mv "$CERT".new "$CERT"
            mv "$KEY".new  "$KEY"
            mv "$CA".new   "$CA"

            echo "cert minted for ${cfg.commonName}"
          elif ! cert_fresh; then
            echo "cert near expiry — renewing via cert auth"
            # Use the existing cert to auth, then mint a new one.
            LOGIN=$(bao login -method=cert -format=json \
              -client-cert="$CERT" -client-key="$KEY" -ca-cert="$CA")
            RENEW_TOKEN=$(echo "$LOGIN" | jq -r '.auth.client_token')

            ISSUE=$(BAO_TOKEN="$RENEW_TOKEN" \
              bao write -format=json \
                ${lib.escapeShellArg cfg.pki.mount}/issue/${lib.escapeShellArg cfg.pki.role} \
                common_name=${lib.escapeShellArg cfg.commonName} \
                ttl=${lib.escapeShellArg cfg.ttl})

            echo "$ISSUE" | jq -r '.data.certificate' > "$CERT".new
            echo "$ISSUE" | jq -r '.data.private_key' > "$KEY".new
            echo "$ISSUE" | jq -r '.data.issuing_ca'  > "$CA".new
            chmod 0400 "$CERT".new "$KEY".new "$CA".new
            mv "$CERT".new "$CERT"
            mv "$KEY".new  "$KEY"
            mv "$CA".new   "$CA"

            echo "cert renewed for ${cfg.commonName}"
          fi

          # Always log in with the (now-valid) cert and write a fresh
          # service token. openbao-kv consumers read this.
          LOGIN=$(bao login -method=cert -format=json \
            -client-cert="$CERT" -client-key="$KEY" -ca-cert="$CA")
          echo "$LOGIN" | jq -r '.auth.client_token' > ${lib.escapeShellArg cfg.tokenFile}.new
          chmod 0600 ${lib.escapeShellArg cfg.tokenFile}.new
          mv ${lib.escapeShellArg cfg.tokenFile}.new ${lib.escapeShellArg cfg.tokenFile}

          echo "authenticated via cert as ${cfg.commonName}"
        '';
      };
    };
}
