{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "openbao"
  ];
  description = "OpenBao secrets management with integrated Raft storage";
  options = {lib, ...}: {
    clusterNodes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "Hostnames of all nodes in the OpenBao cluster.";
    };
    dataNetwork = lib.mkOption {
      type = lib.types.str;
      default = "infra";
    };
    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 8200;
    };
    clusterPort = lib.mkOption {
      type = lib.types.port;
      default = 8201;
    };
    transitTokenFile = lib.mkOption {
      type = lib.types.str;
      description = "Path to file containing the transit auto-unseal token.";
    };

    # -- Authentication --
    authPasswordFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to file containing the userpass auth password for the
        services account.  Pre-generate a random password, store in
        sops, and set this option.  The configure service bootstraps
        userpass auth on first deploy; subsequent deploys just log in.
      '';
    };
    configureTokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Path to a pre-existing OpenBao token.  Used as a fallback when
        userpass auth is not yet enabled (migration from token-based
        auth).  Once userpass is bootstrapped this can be removed.
      '';
    };
    servicesPolicy = lib.mkOption {
      type = lib.types.lines;
      default = ''
        path "kv/*"         { capabilities = ["create","read","update","patch","list"] }
        path "pki/*"        { capabilities = ["create","read","update","list"] }
        path "sys/mounts/*" { capabilities = ["create","read","update","sudo"] }
        path "sys/mounts"   { capabilities = ["read","list"] }
        path "sys/auth/*"   { capabilities = ["create","read","update","sudo"] }
        path "sys/auth"     { capabilities = ["read","list"] }
        path "sys/policies/acl/*" { capabilities = ["create","read","update","list"] }
        path "auth/*"       { capabilities = ["create","read","update","list"] }
      '';
      description = "HCL policy attached to the services user.";
    };

    # -- Auto-init --
    autoInit = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Automatically initialise the cluster on first deploy.";
      };
      recoveryShares = lib.mkOption {
        type = lib.types.int;
        default = 3;
      };
      recoveryThreshold = lib.mkOption {
        type = lib.types.int;
        default = 2;
      };
      recoveryKeyRecipients = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Age public keys used to encrypt recovery keys.  If empty, recovery keys are not persisted.";
      };
    };

    # -- Cluster configuration --
    configure = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = ''
        Idempotent bao CLI commands run after authentication succeeds.
        bao/jq/openssl in PATH, BAO_TOKEN set.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = lib.types.attrsOf lib.types.anything;
        options = {
          ui = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
          storagePath = lib.mkOption {
            type = lib.types.str;
            default = "/var/lib/openbao";
          };
          transitAddress = lib.mkOption {
            type = lib.types.str;
            description = "Address of the transit seal provider (e.g. http://10.0.25.1:8200).";
          };
        };
      };
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
    hardening = {
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
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
    };

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

    eg = config.psyclyx.egregore;
    hostname = config.psyclyx.nixos.host;

    bindAddr = eg.entities.${hostname}.host.addresses.${cfg.dataNetwork}.ipv4;
    otherNodes = builtins.filter (n: n != hostname) cfg.clusterNodes;

    retryJoin =
      map (node: {
        leader_api_addr = "http://${eg.entities.${node}.host.addresses.${cfg.dataNetwork}.ipv4}:${toString cfg.apiPort}";
      })
      otherNodes;

    configData = {
      ui = cfg.settings.ui;
      listener = mkListeners bindAddr cfg.apiPort;
      storage.raft = {
        path = cfg.settings.storagePath;
        node_id = hostname;
        retry_join = retryJoin;
      };
      api_addr = "http://${bindAddr}:${toString cfg.apiPort}";
      cluster_addr = "http://${bindAddr}:${toString cfg.clusterPort}";
      seal.transit = {
        address = cfg.settings.transitAddress;
        disable_renewal = "false";
        key_name = "autounseal";
        mount_path = "transit/";
      };
    };

    configFile = pkgs.writeText "openbao.json" (builtins.toJSON configData);
    runtimeConfig = "/run/openbao/config.json";
    jq = "${pkgs.jq}/bin/jq";

    hasConfigure = cfg.authPasswordFile != null || cfg.configureTokenFile != null;

    ageRecipientArgs = lib.concatMapStringsSep " "
      (key: "-r ${lib.escapeShellArg key}")
      cfg.autoInit.recoveryKeyRecipients;
  in {
    environment.systemPackages = [pkgs.openbao];

    users.users.openbao = {
      isSystemUser = true;
      group = "openbao";
    };
    users.groups.openbao = {};

    systemd.services.openbao = {
      description = "OpenBao Secrets Management";
      after = ["network-online.target" "sops-install-secrets.service"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      environment.BAO_ADDR = "http://127.0.0.1:${toString cfg.apiPort}";

      serviceConfig =
        {
          User = "openbao";
          Group = "openbao";
          ExecStart = "${pkgs.openbao}/bin/bao server -config=${runtimeConfig}";
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          Restart = "on-failure";
          RestartSec = "10s";
          StartLimitIntervalSec = 0;
          StateDirectory = "openbao";
          RuntimeDirectory = "openbao";
        }
        // hardening;

      preStart = ''
        TOKEN=$(cat "${cfg.transitTokenFile}")
        ${jq} --arg token "$TOKEN" \
          '.seal.transit.token = $token' \
          ${configFile} > ${runtimeConfig}
        chmod 600 ${runtimeConfig}
      '';
    };

    # -- Cluster configuration (auth bootstrap + user configure script) --
    systemd.services.openbao-configure = lib.mkIf hasConfigure {
      description = "Configure OpenBao cluster";
      after = ["openbao.service"];
      wants = ["openbao.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "openbao-auth";
        RuntimeDirectoryMode = "0700";
      };
      environment = {
        BAO_ADDR = "http://127.0.0.1:${toString cfg.apiPort}";
        HOME = "/run/openbao-auth";
      };
      path = [pkgs.openbao pkgs.jq pkgs.openssl pkgs.bash] ++ lib.optional cfg.autoInit.enable pkgs.age;
      script = ''
        set -euo pipefail

        # -- Wait for cluster to be reachable --
        # bao writes to an internal fd that command substitution can't capture
        # in some systemd environments, so we use a temp file instead.
        STATUS_FILE=$(mktemp)
        trap "rm -f $STATUS_FILE" EXIT

        for i in $(seq 1 60); do
          bao status -format=json > "$STATUS_FILE" 2>/dev/null || true
          if jq -e '.sealed == false' "$STATUS_FILE" >/dev/null 2>&1; then
            break
          fi
          sleep 2
        done

        INITIALIZED=$(jq -r '.initialized | tostring' "$STATUS_FILE" 2>/dev/null || echo "false")
        SEALED=$(jq -r '.sealed | tostring' "$STATUS_FILE" 2>/dev/null || echo "true")

        # -- Phase 1: Obtain a token --
        ROOT_TOKEN=""

        if [ "$INITIALIZED" = "false" ] && [ "$SEALED" != "false" ]; then
          ${lib.optionalString cfg.autoInit.enable ''
            echo "Cluster not initialized — running auto-init"
            INIT_FILE=$(mktemp)
            bao operator init -format=json \
              -recovery-shares=${toString cfg.autoInit.recoveryShares} \
              -recovery-threshold=${toString cfg.autoInit.recoveryThreshold} > "$INIT_FILE"

            ROOT_TOKEN=$(jq -r '.root_token' "$INIT_FILE")
            export BAO_TOKEN="$ROOT_TOKEN"

            ${if cfg.autoInit.recoveryKeyRecipients != [] then ''
              jq '.recovery_keys_base64' "$INIT_FILE" \
                | age ${ageRecipientArgs} -o /var/lib/openbao/recovery-keys.age
              echo "Recovery keys encrypted to /var/lib/openbao/recovery-keys.age"
            '' else ''
              echo "WARNING: No recovery key recipients configured — recovery keys not persisted"
              echo "Printing recovery keys to journal (capture these NOW):"
              jq -r '.recovery_keys_base64[]' "$INIT_FILE"
            ''}
            rm -f "$INIT_FILE"
          ''}
          ${lib.optionalString (!cfg.autoInit.enable) ''
            echo "Cluster not initialized and autoInit disabled, skipping"
            exit 0
          ''}
        elif [ "$SEALED" = "false" ]; then
          # Cluster is running — try userpass first
          ${lib.optionalString (cfg.authPasswordFile != null) ''
            PASS=$(cat ${lib.escapeShellArg cfg.authPasswordFile})
            LOGIN_FILE=$(mktemp)
            if bao login -method=userpass -format=json \
                  username=services password="$PASS" > "$LOGIN_FILE" 2>/dev/null; then
              export BAO_TOKEN=$(jq -r '.auth.client_token' "$LOGIN_FILE")
            fi
            rm -f "$LOGIN_FILE"
          ''}

          # Fall back to migration token
          ${lib.optionalString (cfg.configureTokenFile != null) ''
            if [ -z "''${BAO_TOKEN:-}" ] && [ -f ${lib.escapeShellArg cfg.configureTokenFile} ]; then
              export BAO_TOKEN=$(cat ${lib.escapeShellArg cfg.configureTokenFile})
            fi
          ''}

          if [ -z "''${BAO_TOKEN:-}" ]; then
            echo "Cannot authenticate — skipping configuration"
            exit 0
          fi
        else
          echo "Cluster sealed, skipping"
          exit 0
        fi

        # -- Phase 2: Bootstrap userpass auth --
        ${lib.optionalString (cfg.authPasswordFile != null) ''
          PASS=$(cat ${lib.escapeShellArg cfg.authPasswordFile})

          AUTH_FILE=$(mktemp)
          bao auth list -format=json > "$AUTH_FILE" 2>/dev/null || true
          if ! jq -e '."userpass/"' "$AUTH_FILE" >/dev/null 2>&1; then
            echo "Enabling userpass auth"
            ENABLE_OUT=$(mktemp)
            if ! bao auth enable userpass > "$ENABLE_OUT" 2>&1; then
              if ! grep -q "path is already in use" "$ENABLE_OUT"; then
                echo "Failed to enable userpass:" >&2
                cat "$ENABLE_OUT" >&2
                rm -f "$ENABLE_OUT" "$AUTH_FILE"
                exit 1
              fi
            fi
            rm -f "$ENABLE_OUT"
          fi
          rm -f "$AUTH_FILE"

          bao policy write lab-services - <<'POLICY'
        ${cfg.servicesPolicy}
        POLICY

          bao write auth/userpass/users/services \
            password="$PASS" \
            policies=lab-services

          # If we used root token from auto-init, switch to services and revoke root
          if [ -n "$ROOT_TOKEN" ]; then
            NEW_LOGIN_FILE=$(mktemp)
            bao login -method=userpass -format=json \
              username=services password="$PASS" > "$NEW_LOGIN_FILE"
            OLD_TOKEN="$BAO_TOKEN"
            export BAO_TOKEN=$(jq -r '.auth.client_token' "$NEW_LOGIN_FILE")
            rm -f "$NEW_LOGIN_FILE"
            BAO_TOKEN="$OLD_TOKEN" bao token revoke -self 2>/dev/null || true
            echo "Root token revoked"
          fi
        ''}

        # -- Phase 3: Run user configure script --
        ${cfg.configure}

        echo "OpenBao cluster configuration converged"
      '';
    };

    # -- Login service: authenticate and write token file for consumers --
    systemd.services.openbao-login = lib.mkIf (cfg.authPasswordFile != null) {
      description = "OpenBao userpass login";
      after = ["openbao.service"] ++ lib.optional hasConfigure "openbao-configure.service";
      wants = ["openbao.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        RuntimeDirectory = "openbao-auth";
        RuntimeDirectoryMode = "0700";
      };
      environment = {
        BAO_ADDR = "http://127.0.0.1:${toString cfg.apiPort}";
        HOME = "/run/openbao-auth";
      };
      path = [pkgs.openbao pkgs.jq pkgs.bash];
      script = ''
        set -euo pipefail
        PASS=$(cat ${lib.escapeShellArg cfg.authPasswordFile})
        TOKEN_FILE="/run/openbao-auth/services-token"

        LOGIN_FILE=$(mktemp)
        for i in $(seq 1 120); do
          if bao login -method=userpass -format=json \
                username=services password="$PASS" > "$LOGIN_FILE" 2>/dev/null; then
            jq -r '.auth.client_token' "$LOGIN_FILE" > "$TOKEN_FILE.new"
            chmod 600 "$TOKEN_FILE.new"
            mv "$TOKEN_FILE.new" "$TOKEN_FILE"
            rm -f "$LOGIN_FILE"
            echo "Authenticated with OpenBao"
            exit 0
          fi
          sleep 2
        done
        rm -f "$LOGIN_FILE"

        echo "WARNING: Could not authenticate after 120 attempts — dependents will use fallbacks"
      '';
    };

    psyclyx.nixos.network.ports.openbao = {
      tcp = [cfg.apiPort cfg.clusterPort];
    };
  };
}
