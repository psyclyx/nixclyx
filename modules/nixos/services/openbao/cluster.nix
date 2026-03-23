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
      {tcp = {address = "${addr}:${toString port}"; tls_disable = true;};}
      {tcp = {address = "127.0.0.1:${toString port}"; tls_disable = true;};}
    ];

    fleet = config.psyclyx.fleet;
    hostname = config.psyclyx.nixos.host;

    bindAddr = fleet.hostAddress hostname cfg.dataNetwork;
    otherNodes = builtins.filter (n: n != hostname) cfg.clusterNodes;

    retryJoin = map (node: {
      leader_api_addr = "http://${fleet.hostAddress node cfg.dataNetwork}:${toString cfg.apiPort}";
    }) otherNodes;

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
  in {
    environment.systemPackages = [pkgs.openbao];

    users.users.openbao = {
      isSystemUser = true;
      group = "openbao";
    };
    users.groups.openbao = {};

    systemd.services.openbao = {
      description = "OpenBao Secrets Management";
      after = ["network-online.target"];
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

    psyclyx.nixos.network.ports.openbao = {
      tcp = [cfg.apiPort cfg.clusterPort];
    };
  };
}
