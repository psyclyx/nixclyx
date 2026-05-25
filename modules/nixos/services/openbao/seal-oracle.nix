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
      authMethods = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "userpass" "cert" ];
        description = ''
          Auth methods to enable on the seal oracle. Each entry is the
          method name as `bao auth enable` expects it; the configure
          script checks `bao auth list` first and skips already-enabled
          methods, so this list is safe to re-apply.
        '';
      };
      kvMounts = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        example = [ "kv" ];
        description = ''
          Paths at which to mount the KV v2 secrets engine. Idempotent;
          existing mounts are left in place.
        '';
      };
      userpassUsers = lib.mkOption {
        type = lib.types.attrsOf (lib.types.submodule {
          options = {
            passwordFile = lib.mkOption {
              type = lib.types.str;
              description = "Path to a file containing the user's password.";
            };
            policies = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
              description = "Policy names attached to the user.";
            };
          };
        });
        default = { };
        description = ''
          Userpass auth users to create. Requires `userpass` to be
          listed in `authMethods` (the auth method is enabled before
          users are written).
        '';
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

      tls = {
        enable = lib.mkEnableOption ''
          TLS on the external listener. The loopback listener stays
          plain HTTP so the local configure hook can run before any
          cert exists. Off → both listeners use tls_disable = true.
        '';
        certFile = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/openbao-seal/listener-cert.pem";
          description = "Path to the TLS cert file on the OpenBao host.";
        };
        keyFile = lib.mkOption {
          type = lib.types.str;
          default = "/var/lib/openbao-seal/listener-key.pem";
          description = "Path to the TLS key file on the OpenBao host.";
        };
        commonName = lib.mkOption {
          type = lib.types.str;
          default = "openbao";
          description = ''
            CN to put on the self-signed cert generated at first
            boot. Only used when the cert/key files don't exist
            yet; rotation/upgrade is a separate concern.
          '';
        };
        subjectAltNames = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            DNS/IP SubjectAltNames for the generated self-signed cert.
            Format: "DNS:openbao.example.org" or "IP:10.0.25.1".
          '';
        };
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

      # External listener: TLS-on if cfg.tls.enable, otherwise plain.
      # Loopback always plain HTTP — the configure script + local
      # cert-publish run here before any cert exists, and the
      # loopback path stays cheap.
      mkListeners = addr: port: [
        ({
          tcp = {
            address = "${addr}:${toString port}";
          } // (
            if cfg.tls.enable then {
              tls_cert_file = cfg.tls.certFile;
              tls_key_file = cfg.tls.keyFile;
            } else {
              tls_disable = true;
            }
          );
        })
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

      authMethodsScript = lib.concatMapStringsSep "\n" (method: ''
        if ! bao auth list -format=json | jq -e '."${method}/"' >/dev/null 2>&1; then
          bao auth enable ${lib.escapeShellArg method}
        fi
      '') cfg.authMethods;

      kvMountsScript = lib.concatMapStringsSep "\n" (mount: ''
        if ! bao secrets list -format=json | jq -e '."${mount}/"' >/dev/null 2>&1; then
          bao secrets enable -path=${lib.escapeShellArg mount} kv-v2
        fi
      '') cfg.kvMounts;

      userpassUsersScript = lib.concatStrings (lib.mapAttrsToList (name: u: ''
        bao write auth/userpass/users/${lib.escapeShellArg name} \
          password=@${u.passwordFile} \
          policies=${lib.escapeShellArg (lib.concatStringsSep "," u.policies)}
      '') cfg.userpassUsers);

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

        path = lib.optional cfg.tls.enable pkgs.openssl;
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
        ''
        + lib.optionalString cfg.tls.enable ''
          # Self-signed listener cert at first boot. Subsequent
          # rotations / PKI-issued replacements are out of scope of
          # this preStart — the certFile/keyFile values can be
          # overwritten in-place and the listener picks them up on
          # SIGHUP (ExecReload).
          if [ ! -s ${lib.escapeShellArg cfg.tls.certFile} ] \
             || [ ! -s ${lib.escapeShellArg cfg.tls.keyFile} ]; then
            umask 077
            ${pkgs.openssl}/bin/openssl req -x509 -nodes -days 3650 \
              -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
              -keyout ${lib.escapeShellArg cfg.tls.keyFile} \
              -out ${lib.escapeShellArg cfg.tls.certFile} \
              -subj ${lib.escapeShellArg "/CN=${cfg.tls.commonName}"} \
              ${lib.optionalString (cfg.tls.subjectAltNames != [ ]) ''
                -addext ${lib.escapeShellArg "subjectAltName=${lib.concatStringsSep "," cfg.tls.subjectAltNames}"}
              ''}
          fi
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

            ${authMethodsScript}
            ${kvMountsScript}
            ${userpassUsersScript}

            ${cfg.configure}

            echo "Seal oracle configuration converged"
        '';
      };

      psyclyx.nixos.network.ports.openbao-seal = [ port ];
    };
}
