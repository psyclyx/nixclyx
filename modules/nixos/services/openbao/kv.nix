{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "openbao-kv"
  ];
  description = "OpenBao KV secret consumption";
  options =
    { lib, ... }:
    {
      vaultAddr = lib.mkOption {
        type = lib.types.str;
        default = "http://127.0.0.1:8200";
        description = "OpenBao API address.";
      };
      tokenFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to file containing the OpenBao token for KV operations.";
      };
      secrets = lib.mkOption {
        type = lib.types.attrsOf (
          lib.types.submodule {
            options = {
              kvMount = lib.mkOption {
                type = lib.types.str;
                default = "kv";
                description = "KV v2 mount path.";
              };
              kvPath = lib.mkOption {
                type = lib.types.str;
                description = "Path within the KV mount.";
              };
              renderScript = lib.mkOption {
                type = lib.types.str;
                default = "cat";
                description = ''
                  Script that receives the KV data JSON on stdin and outputs
                  the final file content on stdout.  jq is available in PATH.
                '';
              };
              outputFile = lib.mkOption {
                type = lib.types.str;
                description = "Destination path for the rendered secret.";
              };
              fallbackScript = lib.mkOption {
                type = lib.types.nullOr lib.types.str;
                default = null;
                description = ''
                  If set, run this script (stdout → output file) when OpenBao
                  is unavailable and no output file exists yet.  Allows services
                  to start before OpenBao is bootstrapped.
                '';
              };
              owner = lib.mkOption {
                type = lib.types.str;
                default = "root";
              };
              group = lib.mkOption {
                type = lib.types.str;
                default = "root";
              };
              mode = lib.mkOption {
                type = lib.types.str;
                default = "0400";
              };
              reloadUnits = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [ ];
              };
              renewInterval = lib.mkOption {
                type = lib.types.str;
                default = "1h";
              };
            };
          }
        );
        default = { };
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
      bao = "${pkgs.openbao}/bin/bao";
      jq = "${pkgs.jq}/bin/jq";

      mkSecretService =
        name: secret:
        let
          reloadCmds = lib.concatMapStringsSep "\n" (
            unit: "systemctl reload-or-restart --no-block ${lib.escapeShellArg unit} 2>/dev/null || true"
          ) secret.reloadUnits;
        in
        {
          service = {
            description = "OpenBao KV secret: ${name}";
            after = [
              "network-online.target"
              "openbao.service"
              "openbao-login.service"
            ];
            wants = [ "network-online.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig.Type = "oneshot";
            environment.HOME = "/tmp";
            path = [
              pkgs.jq
              pkgs.bash
            ];
            script = ''
              set -euo pipefail
              DIR=$(dirname ${lib.escapeShellArg secret.outputFile})
              mkdir -p "$DIR"

              FETCHED=0
              if [ -f ${lib.escapeShellArg cfg.tokenFile} ]; then
                export BAO_ADDR=${lib.escapeShellArg cfg.vaultAddr}
                export BAO_TOKEN="$(cat ${lib.escapeShellArg cfg.tokenFile})"
                RESPONSE_FILE=$(mktemp)
                if ${bao} kv get -mount=${lib.escapeShellArg secret.kvMount} -format=json ${lib.escapeShellArg secret.kvPath} > "$RESPONSE_FILE" 2>/dev/null; then
                  ( ${jq} '.data.data' "$RESPONSE_FILE" | ${secret.renderScript} ) > ${lib.escapeShellArg secret.outputFile}.new
                  chown ${secret.owner}:${secret.group} ${lib.escapeShellArg secret.outputFile}.new
                  chmod ${secret.mode} ${lib.escapeShellArg secret.outputFile}.new
                  mv ${lib.escapeShellArg secret.outputFile}.new ${lib.escapeShellArg secret.outputFile}
                  FETCHED=1
                  echo "Fetched KV secret ${secret.kvPath} from OpenBao"
                fi
                rm -f "$RESPONSE_FILE"
              fi

              if [ "$FETCHED" -eq 0 ] && [ ! -f ${lib.escapeShellArg secret.outputFile} ]; then
                ${
                  if secret.fallbackScript != null then
                    ''
                      echo "OpenBao unavailable, running fallback for ${name}"
                      ( ${secret.fallbackScript} ) > ${lib.escapeShellArg secret.outputFile}.new
                      chown ${secret.owner}:${secret.group} ${lib.escapeShellArg secret.outputFile}.new
                      chmod ${secret.mode} ${lib.escapeShellArg secret.outputFile}.new
                      mv ${lib.escapeShellArg secret.outputFile}.new ${lib.escapeShellArg secret.outputFile}
                    ''
                  else
                    ''
                      echo "OpenBao unavailable and no fallback configured for ${name}, skipping"
                    ''
                }
              elif [ "$FETCHED" -eq 0 ]; then
                echo "OpenBao unavailable, keeping existing ${name}"
              fi

              ${lib.optionalString (secret.reloadUnits != [ ]) ''
                if [ "$FETCHED" -eq 1 ]; then
                  ${reloadCmds}
                fi
              ''}
            '';
          };
          timer = {
            description = "Renew OpenBao KV secret: ${name}";
            wantedBy = [ "timers.target" ];
            timerConfig = {
              OnUnitActiveSec = secret.renewInterval;
              RandomizedDelaySec = "5m";
            };
          };
        };

      secretConfigs = lib.mapAttrs mkSecretService cfg.secrets;
    in
    {
      systemd.services =
        lib.mapAttrs' (name: c: lib.nameValuePair "openbao-kv-${name}" c.service) secretConfigs
        // (lib.mkMerge (
          lib.flatten (
            lib.mapAttrsToList (
              secretName: secret:
              map (unit: {
                "${lib.removeSuffix ".service" unit}" = {
                  after = [ "openbao-kv-${secretName}.service" ];
                  wants = [ "openbao-kv-${secretName}.service" ];
                };
              }) secret.reloadUnits
            ) cfg.secrets
          )
        ));
      systemd.timers = lib.mapAttrs' (
        name: c: lib.nameValuePair "openbao-kv-${name}" c.timer
      ) secretConfigs;
    };
}
