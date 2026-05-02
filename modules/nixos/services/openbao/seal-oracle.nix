{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "openbao-seal-oracle"
  ];
  description = "OpenBao standalone seal oracle";
  options =
    { lib, ... }:
    {
      bindAddress = lib.mkOption {
        type = lib.types.str;
        description = "IP address to bind the API listener on.";
      };
      apiPort = lib.mkOption {
        type = lib.types.port;
        default = 8200;
      };
      seal = lib.mkOption {
        type = lib.types.submodule {
          freeformType = lib.types.attrsOf lib.types.str;
          options.type = lib.mkOption {
            type = lib.types.str;
            default = "pkcs11";
          };
          options.secretField = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Seal attribute whose value is injected from secretFile at runtime (e.g. \"pin\").";
          };
        };
        description = "Seal stanza configuration.";
      };
      secretFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file whose contents are injected into the seal field named by seal.secretField.";
      };
      serviceEnvironment = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
      };
      rootTokenFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to file containing the root token (for the configure service).";
      };
      configure = lib.mkOption {
        type = lib.types.lines;
        default = "";
        description = "Extra bao CLI commands run after transit engine bootstrap. bao/jq in PATH, BAO_TOKEN set. Runs under set -euo pipefail.";
      };
      pki = {
        enable = lib.mkEnableOption "PKI secrets engine with root CA";
        commonName = lib.mkOption {
          type = lib.types.str;
          description = "Common name for the root CA certificate.";
        };
        maxTtl = lib.mkOption {
          type = lib.types.str;
          default = "87600h";
          description = "Maximum lease TTL for the PKI engine.";
        };
        roles = lib.mkOption {
          type = lib.types.listOf (
            lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Role name.";
                };
                allowedDomains = lib.mkOption {
                  type = lib.types.str;
                  description = "Allowed domains for certificates.";
                };
                allowSubdomains = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                };
                allowIpSans = lib.mkOption {
                  type = lib.types.bool;
                  default = true;
                };
                maxTtl = lib.mkOption {
                  type = lib.types.str;
                  default = "720h";
                };
              };
            }
          );
          default = [ ];
          description = "PKI roles to create.";
        };
      };
      tpm.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
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
      hardening =
        tpmAccess:
        {
          NoNewPrivileges = true;
          ProtectSystem = "strict";
          ProtectHome = true;
          PrivateTmp = true;
          ProtectKernelTunables = true;
          ProtectKernelModules = true;
          ProtectKernelLogs = true;
          ProtectControlGroups = true;
          RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX AF_NETLINK";
          RestrictNamespaces = true;
          RestrictRealtime = true;
          LockPersonality = true;
          LimitNOFILE = 65536;
          LimitMEMLOCK = "infinity";
          AmbientCapabilities = "CAP_IPC_LOCK";
          CapabilityBoundingSet = "CAP_SYSLOG CAP_IPC_LOCK";
          RuntimeDirectoryMode = "0700";
        }
        // (
          if tpmAccess then
            {
              PrivateDevices = false;
              DeviceAllow = [
                "/dev/tpm0 rw"
                "/dev/tpmrm0 rw"
              ];
            }
          else
            { PrivateDevices = true; }
        );

      mkListeners = addr: port: [
        {
          tcp = {
            address = "${addr}:${toString port}";
            tls_disable = true;
          };
        }
        {
          tcp = {
            address = "127.0.0.1:${toString port}";
            tls_disable = true;
          };
        }
      ];

      port = cfg.apiPort;
      addr = cfg.bindAddress;

      sealType = cfg.seal.type;
      hasSecret = cfg.seal.secretField != null;
      sealAttrs = builtins.removeAttrs cfg.seal (
        [
          "type"
          "secretField"
        ]
        ++ lib.optional hasSecret cfg.seal.secretField
      );

      configData = {
        ui = false;
        listener = mkListeners addr port;
        storage.file.path = "/var/lib/openbao-seal";
        api_addr = "http://${addr}:${toString port}";
        seal.${sealType} = sealAttrs;
      };

      pkiScript = lib.optionalString cfg.pki.enable ''
        # -- PKI engine --
        if ! OUTPUT=$(bao secrets enable pki 2>&1); then
          if echo "$OUTPUT" | grep -q "path is already in use"; then
            echo "PKI engine already enabled"
          else
            echo "Failed to enable PKI engine: $OUTPUT" >&2
            exit 1
          fi
        fi

        bao secrets tune -max-lease-ttl=${cfg.pki.maxTtl} pki

        if ! bao read pki/cert/ca >/dev/null 2>&1; then
          bao write pki/root/generate/internal \
            common_name="${cfg.pki.commonName}" \
            ttl=${cfg.pki.maxTtl}
        fi

        ${lib.concatStringsSep "\n" (
          map (role: ''
            bao write pki/roles/${role.name} \
              allowed_domains="${role.allowedDomains}" \
              allow_subdomains=${lib.boolToString role.allowSubdomains} \
              allow_ip_sans=${lib.boolToString role.allowIpSans} \
              max_ttl=${role.maxTtl}
          '') cfg.pki.roles
        )}
      '';

      configFile = pkgs.writeText "openbao-seal-oracle.json" (builtins.toJSON configData);
      runtimeConfig = "/run/openbao-seal/config.json";
      jq = "${pkgs.jq}/bin/jq";

      autounsealPolicy = pkgs.writeText "openbao-autounseal-policy.hcl" ''
        path "transit/encrypt/autounseal" { capabilities = ["update"] }
        path "transit/decrypt/autounseal" { capabilities = ["update"] }
      '';
    in
    {
      assertions = [
        {
          assertion = !hasSecret || cfg.secretFile != null;
          message = "openbao-seal-oracle: secretFile must be set when seal.secretField is set";
        }
      ];

      security.tpm2 = lib.mkIf cfg.tpm.enable {
        enable = true;
        pkcs11.enable = true;
        tctiEnvironment.enable = true;
      };
      environment.systemPackages = [
        pkgs.openbao
      ]
      ++ lib.optionals cfg.tpm.enable [
        pkgs.tpm2-tools
        pkgs.tpm2-pkcs11
      ];

      users.users.openbao-seal = {
        isSystemUser = true;
        group = "openbao-seal";
        extraGroups = lib.optionals cfg.tpm.enable [ "tss" ];
      };
      users.groups.openbao-seal = { };

      systemd.services.openbao-seal = {
        description = "OpenBao Seal Oracle";
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        wantedBy = [ "multi-user.target" ];

        environment = {
          BAO_ADDR = "http://127.0.0.1:${toString port}";
        }
        // cfg.serviceEnvironment;

        serviceConfig = {
          User = "openbao-seal";
          Group = "openbao-seal";
          ExecStart = "${pkgs.openbao}/bin/bao server -config=${runtimeConfig}";
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          Restart = "on-failure";
          RestartSec = "5s";
          StartLimitIntervalSec = 0;
          StateDirectory = "openbao-seal";
          RuntimeDirectory = "openbao-seal";
        }
        // hardening cfg.tpm.enable;

        preStart = ''
          ${
            if hasSecret then
              ''
                SECRET=$(cat "${cfg.secretFile}")
                ${jq} --arg secret "$SECRET" \
                  '.seal.${sealType}.${cfg.seal.secretField} = $secret' \
                  ${configFile} > ${runtimeConfig}
              ''
            else
              ''
                cp ${configFile} ${runtimeConfig}
              ''
          }
          chmod 600 ${runtimeConfig}
        '';
      };

      systemd.services.openbao-seal-configure = {
        description = "Configure OpenBao seal oracle";
        after = [ "openbao-seal.service" ];
        wants = [ "openbao-seal.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = "openbao-seal";
          Group = "openbao-seal";
        };
        environment.BAO_ADDR = "http://127.0.0.1:${toString port}";
        path = [
          pkgs.openbao
          pkgs.jq
        ];
        script = ''
            set -euo pipefail
            export BAO_TOKEN=$(cat "${cfg.rootTokenFile}")

            STATUS=""
            for i in $(seq 1 30); do
              if STATUS=$(bao status -format=json 2>/dev/null); then
                break
              fi
              sleep 2
            done

            if ! echo "$STATUS" | jq -e '.initialized and (.sealed | not)' >/dev/null 2>&1; then
              echo "Not initialized or sealed, skipping configuration"
              exit 0
            fi

            if ! OUTPUT=$(bao secrets enable transit 2>&1); then
              if echo "$OUTPUT" | grep -q "path is already in use"; then
                echo "Transit engine already enabled"
              else
                echo "Failed to enable transit engine: $OUTPUT" >&2
                exit 1
              fi
            fi

            if ! bao read transit/keys/autounseal >/dev/null 2>&1; then
              bao write -f transit/keys/autounseal
            fi

            bao policy write autounseal ${autounsealPolicy}

            ${pkiScript}

            ${cfg.configure}

            echo "Seal oracle configuration converged"
        '';
      };

      psyclyx.nixos.network.ports.openbao-seal = [ port ];
    };
}
