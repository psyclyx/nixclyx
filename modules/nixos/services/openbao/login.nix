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
        };

        environment = {
          BAO_ADDR = cfg.vaultAddr;
          HOME = "/run/openbao-auth";
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
          for i in $(seq 1 120); do
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

          echo "WARNING: Could not authenticate with ${cfg.vaultAddr} after 120 attempts"
          # Don't fail — dependents using openbao-kv have a fallback path.
          exit 0
        '';
      };
    };
}
