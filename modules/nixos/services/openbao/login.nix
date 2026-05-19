# Generic OpenBao userpass login.
#
# Authenticates a host against an OpenBao instance (typically the lab
# cluster's HA endpoint) using the `services` userpass user, and writes
# the resulting token to a runtime path that openbao-kv consumers and
# other clients can read.
#
# This is the standalone version of the openbao-login service that
# previously lived inside the cluster module. Non-cluster hosts (iyr,
# tleilax) use this to authenticate against the cluster.
{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "openbao-login"
  ];
  description = "OpenBao userpass login";
  options =
    { lib, ... }:
    {
      enable = lib.mkEnableOption "OpenBao userpass login service";

      vaultAddr = lib.mkOption {
        type = lib.types.str;
        description = ''
          OpenBao API endpoint to authenticate against. Typically the
          lab cluster's HA VIP, e.g. http://10.0.25.200:8200.
        '';
      };

      authPasswordFile = lib.mkOption {
        type = lib.types.path;
        description = "Path to the userpass password for the services user.";
      };

      tokenFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/openbao-auth/services-token";
        description = "Path where the issued token is written.";
      };

      username = lib.mkOption {
        type = lib.types.str;
        default = "services";
        description = "Userpass username.";
      };

      insecureSkipVerify = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Skip TLS verification of the OpenBao server cert. Use this
          for self-signed listener certs on a trusted network. The
          login itself is still TLS-encrypted; we just don't verify
          the server's identity.
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
      systemd.services.openbao-login = {
        description = "OpenBao userpass login (${cfg.username} → ${cfg.vaultAddr})";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "openbao-auth";
          RuntimeDirectoryMode = "0700";
          # Backstop: if the script gets wedged (e.g. unreachable
          # endpoint with slow TCP timeouts), systemd kills it. The
          # in-script loop is bounded to ~20s, so 60s is plenty.
          TimeoutStartSec = "60s";
        };

        # Hourly retry — if OpenBao was unreachable at boot, we'll pick
        # up an authenticated token within an hour of it coming back.
        startAt = "hourly";

        environment = {
          BAO_ADDR = cfg.vaultAddr;
          HOME = "/run/openbao-auth";
          # Cap each `bao login` attempt's HTTP timeout (default is 60s).
          # We want fail-fast on connection problems, not a long wait.
          VAULT_CLIENT_TIMEOUT = "5";
        } // lib.optionalAttrs cfg.insecureSkipVerify {
          VAULT_SKIP_VERIFY = "true";
        };

        path = [
          pkgs.openbao
          pkgs.jq
          pkgs.bash
        ];

        script = ''
          set -euo pipefail
          PASS=$(cat ${lib.escapeShellArg cfg.authPasswordFile})

          LOGIN_FILE=$(mktemp)
          # Short retry budget — boot must not wait long on this. The
          # systemd timer rearms hourly so a transient unreachable
          # endpoint self-heals later.
          for i in $(seq 1 5); do
            if bao login -method=userpass -format=json \
                  username=${lib.escapeShellArg cfg.username} \
                  password="$PASS" > "$LOGIN_FILE" 2>/dev/null; then
              jq -r '.auth.client_token' "$LOGIN_FILE" > ${lib.escapeShellArg cfg.tokenFile}.new
              chmod 600 ${lib.escapeShellArg cfg.tokenFile}.new
              mv ${lib.escapeShellArg cfg.tokenFile}.new ${lib.escapeShellArg cfg.tokenFile}
              rm -f "$LOGIN_FILE"
              echo "Authenticated with OpenBao at ${cfg.vaultAddr}"
              exit 0
            fi
            sleep 2
          done
          rm -f "$LOGIN_FILE"

          echo "WARNING: Could not authenticate with ${cfg.vaultAddr} after 5 attempts"
          # Don't fail — dependents using openbao-kv have a fallback path,
          # and the hourly timer will retry.
          exit 0
        '';
      };
    };
}
