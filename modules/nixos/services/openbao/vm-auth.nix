# OpenBao cert-auth for microvm guests.
#
# Two concerns in one unit:
#   1. **Bootstrap** — when the cert is missing or already expired
#      (cert-auth renewal is impossible once it lapses), unwrap a
#      one-time wrap token shared in by the hypervisor, mint a client
#      cert via the configured PKI role, and store it in the VM's
#      persistent state directory. A still-valid, near-expiry cert
#      renews itself via cert auth instead (falling back to bootstrap).
#   2. **Login** — auth to OpenBao with the persisted cert and write
#      the resulting service token to /run/openbao-auth/services-token
#      so downstream `openbao-kv` consumers can fetch secrets.
#
# Fleet-agnostic: the hypervisor-side projection mints the wrap
# tokens; this guest-side module just expects the token file to be
# present when no cert exists yet.
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
        example = "service-vm";
      };

      commonName = lib.mkOption {
        type = lib.types.str;
        description = "Subject CN requested from PKI. Must match the cert auth method's allowed_common_names_glob.";
        example = "api.service.internal";
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
          File holding the short-TTL wrap token the hypervisor placed
          here via virtiofs share. Consumed on cert mint — both the
          first bootstrap and any later re-bootstrap after the cert has
          expired. Not used on the normal cert-auth renewal path. The
          hypervisor re-mints this on every guest (re)start so it is
          fresh whenever a bootstrap is actually needed.
        '';
      };

      insecureSkipVerify = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Skip server-cert verification when talking to OpenBao.
          Independent of the cert auth method itself (which uses the
          guest's *client* cert in the TLS handshake) — this only
          controls whether we verify the OpenBao listener's cert.
          Useful when the listener has a self-signed cert and the
          fleet doesn't yet have CA distribution wired.
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
    lib.mkIf cfg.enable (let
      # Parse "<n><unit>" (e.g. "168h") into seconds at eval time so
      # the runtime script doesn't have to do shell substring math
      # on Nix-interpolated values.
      parseInterval = s:
        let
          unit = lib.substring (lib.stringLength s - 1) 1 s;
          n = lib.toInt (lib.substring 0 (lib.stringLength s - 1) s);
        in
        if unit == "h" then n * 3600
        else if unit == "m" then n * 60
        else if unit == "s" then n
        else throw "openbao-vm-auth: renewMargin '${s}' must end in h/m/s";
      renewMarginSec = parseInterval cfg.renewMargin;
    in {
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
        } // lib.optionalAttrs cfg.insecureSkipVerify {
          VAULT_SKIP_VERIFY = "true";
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
          WRAP_TOKEN_FILE=${lib.escapeShellArg cfg.wrapTokenFile}

          # `openssl x509 -checkend N` returns 0 iff cert is NOT
          # expiring within N seconds. renewMarginSec comes from
          # Nix-evaluated parseInterval at build time.
          cert_fresh() {
            [ -s "$CERT" ] || return 1
            openssl x509 -checkend ${toString renewMarginSec} -noout -in "$CERT" >/dev/null 2>&1
          }

          # Cert exists and has not yet passed its notAfter. A cert that
          # fails this can no longer authenticate, so it cannot be
          # renewed via cert auth — it must be re-bootstrapped.
          cert_valid() {
            [ -s "$CERT" ] || return 1
            openssl x509 -checkend 0 -noout -in "$CERT" >/dev/null 2>&1
          }

          # Issue a leaf cert using $1 as the OpenBao token and install
          # it atomically. PKI returns cert, private key, CA chain.
          mint_cert() {
            local issue
            issue=$(BAO_TOKEN="$1" \
              bao write -format=json \
                ${lib.escapeShellArg cfg.pki.mount}/issue/${lib.escapeShellArg cfg.pki.role} \
                common_name=${lib.escapeShellArg cfg.commonName} \
                ttl=${lib.escapeShellArg cfg.ttl})
            echo "$issue" | jq -r '.data.certificate' > "$CERT".new
            echo "$issue" | jq -r '.data.private_key' > "$KEY".new
            echo "$issue" | jq -r '.data.issuing_ca'  > "$CA".new
            chmod 0400 "$CERT".new "$KEY".new "$CA".new
            mv "$CERT".new "$CERT"
            mv "$KEY".new  "$KEY"
            mv "$CA".new   "$CA"
          }

          # First-boot / recovery path: unwrap the one-time token the
          # hypervisor shared in and mint a cert with it. Needs a
          # *fresh* wrap token (short TTL) — the hypervisor re-mints one
          # every time the guest (re)starts, so a reboot/redeploy heals
          # an expired cert without operator intervention.
          bootstrap_cert() {
            if [ ! -s "$WRAP_TOKEN_FILE" ]; then
              echo "no wrap token at $WRAP_TOKEN_FILE — cannot bootstrap (will retry)"
              return 1
            fi
            echo "bootstrapping cert via wrap token"
            local unwrapped
            unwrapped=$(BAO_TOKEN="$(cat "$WRAP_TOKEN_FILE")" bao unwrap -format=json)
            mint_cert "$(echo "$unwrapped" | jq -r '.auth.client_token')"
            echo "cert minted for ${cfg.commonName}"
          }

          # Renew using the still-valid cert to authenticate. Returns
          # nonzero on failure so the caller can fall back to bootstrap.
          renew_cert() {
            local login
            login=$(bao login -method=cert -format=json \
              -client-cert="$CERT" -client-key="$KEY" -ca-cert="$CA") || return 1
            mint_cert "$(echo "$login" | jq -r '.auth.client_token')"
            echo "cert renewed for ${cfg.commonName}"
          }

          # No cert, or an expired one, can't cert-auth — re-bootstrap
          # via a fresh wrap token. Only a still-valid but near-expiry
          # cert takes the cert-auth renewal path, with a bootstrap
          # fallback if that fails (e.g. after a revocation).
          if ! cert_valid; then
            bootstrap_cert
          elif ! cert_fresh; then
            echo "cert near expiry — renewing via cert auth"
            renew_cert || {
              echo "cert-auth renewal failed — falling back to wrap-token bootstrap"
              bootstrap_cert
            }
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
    });
}
