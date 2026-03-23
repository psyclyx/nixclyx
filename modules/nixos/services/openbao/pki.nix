{
  path = ["psyclyx" "nixos" "services" "openbao-pki"];
  description = "OpenBao PKI certificate management";
  options = {lib, ...}: {
    vaultAddr = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:8200";
      description = "OpenBao API address.";
    };
    tokenFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to file containing the OpenBao token for PKI operations.";
    };
    certificates = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          pkiPath = lib.mkOption {
            type = lib.types.str;
            default = "pki";
          };
          role = lib.mkOption {
            type = lib.types.str;
          };
          commonName = lib.mkOption {
            type = lib.types.str;
          };
          altNames = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
          ipSans = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
          ttl = lib.mkOption {
            type = lib.types.str;
            default = "24h";
          };
          renewInterval = lib.mkOption {
            type = lib.types.str;
            default = "8h";
          };
          directory = lib.mkOption {
            type = lib.types.str;
          };
          owner = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
          group = lib.mkOption {
            type = lib.types.str;
            default = "root";
          };
          reloadUnits = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
          };
        };
      });
      default = {};
    };
  };

  config = {
    cfg,
    config,
    lib,
    pkgs,
    ...
  }: let
    bao = "${pkgs.openbao}/bin/bao";
    jq = "${pkgs.jq}/bin/jq";
    openssl = "${pkgs.openssl}/bin/openssl";

    mkCertService = name: cert: let
      writeArgs =
        "${cert.pkiPath}/issue/${cert.role}"
        + " common_name=${cert.commonName}"
        + " ttl=${cert.ttl}"
        + lib.optionalString (cert.altNames != [])
          " alt_names=${lib.concatStringsSep "," cert.altNames}"
        + lib.optionalString (cert.ipSans != [])
          " ip_sans=${lib.concatStringsSep "," cert.ipSans}";

      reloadCmds = lib.concatMapStringsSep "\n" (unit:
        "systemctl reload-or-restart --no-block ${lib.escapeShellArg unit} 2>/dev/null || true"
      ) cert.reloadUnits;
    in {
      service = {
        description = "OpenBao PKI certificate: ${name}";
        after = ["network-online.target" "openbao.service"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];
        serviceConfig.Type = "oneshot";
        script = ''
          set -euo pipefail
          DIR="${cert.directory}"
          mkdir -p "$DIR"

          FETCHED=0
          if [ -f ${lib.escapeShellArg cfg.tokenFile} ]; then
            export BAO_ADDR="${cfg.vaultAddr}"
            export BAO_TOKEN="$(cat ${lib.escapeShellArg cfg.tokenFile})"
            if RESPONSE=$(${bao} write -format=json ${writeArgs} 2>/dev/null); then
              echo "$RESPONSE" | ${jq} -r '.data.certificate' > "$DIR/cert.pem.new"
              echo "$RESPONSE" | ${jq} -r '.data.private_key' > "$DIR/key.pem.new"
              echo "$RESPONSE" | ${jq} -r '.data.issuing_ca' > "$DIR/ca.pem.new"

              mv "$DIR/cert.pem.new" "$DIR/cert.pem"
              mv "$DIR/key.pem.new" "$DIR/key.pem"
              mv "$DIR/ca.pem.new" "$DIR/ca.pem"
              FETCHED=1
              echo "Fetched certificate for ${cert.commonName} from OpenBao"
            fi
          fi

          if [ "$FETCHED" -eq 0 ] && [ ! -f "$DIR/cert.pem" ]; then
            echo "OpenBao unavailable, generating self-signed certificate for ${cert.commonName}"
            ${openssl} req -x509 \
              -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
              -keyout "$DIR/key.pem" -out "$DIR/cert.pem" \
              -days 1 -nodes -subj "/CN=${cert.commonName}" 2>/dev/null
            cp "$DIR/cert.pem" "$DIR/ca.pem"
          elif [ "$FETCHED" -eq 0 ]; then
            echo "OpenBao unavailable, keeping existing certificate"
          fi

          chown ${cert.owner}:${cert.group} "$DIR/cert.pem" "$DIR/key.pem" "$DIR/ca.pem"
          chmod 644 "$DIR/cert.pem" "$DIR/ca.pem"
          chmod 600 "$DIR/key.pem"

          ${lib.optionalString (cert.reloadUnits != []) ''
            if [ "$FETCHED" -eq 1 ]; then
              ${reloadCmds}
            fi
          ''}
        '';
      };
      timer = {
        description = "Renew OpenBao PKI certificate: ${name}";
        wantedBy = ["timers.target"];
        timerConfig = {
          OnUnitActiveSec = cert.renewInterval;
          RandomizedDelaySec = "5m";
        };
      };
    };

    certConfigs = lib.mapAttrs mkCertService cfg.certificates;
  in {
    systemd.services = lib.mapAttrs' (name: c:
      lib.nameValuePair "openbao-pki-${name}" c.service
    ) certConfigs;
    systemd.timers = lib.mapAttrs' (name: c:
      lib.nameValuePair "openbao-pki-${name}" c.timer
    ) certConfigs;
  };
}
