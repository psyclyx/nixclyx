{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "nomad"
  ];
  description = "Nomad workload orchestrator";
  options =
    { lib, ... }:
    {
      clusterNodes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Hostnames of all Nomad server nodes.";
      };
      dataNetwork = lib.mkOption {
        type = lib.types.str;
        default = "infra";
        description = "Topology network for cluster traffic.";
      };
      datacenter = lib.mkOption {
        type = lib.types.str;
        default = "psyclyx";
      };
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/nomad";
      };
      httpPort = lib.mkOption {
        type = lib.types.port;
        default = 4646;
      };
      rpcPort = lib.mkOption {
        type = lib.types.port;
        default = 4647;
      };
      serfPort = lib.mkOption {
        type = lib.types.port;
        default = 4648;
      };
      encryptionKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file containing the gossip encryption key (from `nomad operator gossip keyring generate`).";
      };
      consul = {
        address = lib.mkOption {
          type = lib.types.str;
          default = "127.0.0.1:8500";
          description = "Consul HTTP API address for service registration.";
        };
        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Path to file containing the Consul ACL token for Nomad.";
        };
      };
      vault = {
        address = lib.mkOption {
          type = lib.types.str;
          description = "OpenBao API address (e.g. http://10.0.25.200:8200).";
        };
        tokenFile = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Path to file containing the OpenBao token for Nomad.";
        };
      };
      nodePool = lib.mkOption {
        type = lib.types.str;
        default = "default";
        description = "Nomad node pool for this client.";
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
      fleet = config.psyclyx.fleet;
      hostname = config.psyclyx.nixos.host;

      bindAddr = fleet.hostAddress hostname cfg.dataNetwork;
      otherNodes = builtins.filter (n: n != hostname) cfg.clusterNodes;
      retryJoinAddrs = map (n: fleet.hostAddress n cfg.dataNetwork) otherNodes;

      hasEncrypt = cfg.encryptionKeyFile != null;
      hasConsulToken = cfg.consul.tokenFile != null;
      hasVaultToken = cfg.vault.tokenFile != null;

      configData = {
        datacenter = cfg.datacenter;
        data_dir = cfg.dataDir;
        bind_addr = bindAddr;

        advertise = {
          http = bindAddr;
          rpc = bindAddr;
          serf = bindAddr;
        };

        ports = {
          http = cfg.httpPort;
          rpc = cfg.rpcPort;
          serf = cfg.serfPort;
        };

        server = {
          enabled = true;
          bootstrap_expect = builtins.length cfg.clusterNodes;
          server_join.retry_join = retryJoinAddrs;
        } // lib.optionalAttrs hasEncrypt {
          encrypt = "__NOMAD_GOSSIP_KEY__";
        };

        client = {
          enabled = true;
          node_pool = cfg.nodePool;
          network_interface = fleet.hostInterface hostname cfg.dataNetwork;
        };

        consul = {
          address = cfg.consul.address;
          auto_advertise = true;
          server_auto_join = false;
          client_auto_join = false;
        } // lib.optionalAttrs hasConsulToken {
          token = "__CONSUL_TOKEN__";
        };

        vault = {
          enabled = true;
          address = cfg.vault.address;
        } // lib.optionalAttrs hasVaultToken {
          token = "__VAULT_TOKEN__";
        };

        plugin.exec = {
          config.no_pivot_root = false;
        };

        telemetry = {
          publish_allocation_metrics = true;
          publish_node_metrics = true;
          prometheus_metrics = true;
        };
      };

      configFile = pkgs.writeText "nomad.json" (builtins.toJSON configData);
    in
    {
      systemd.services.nomad = {
        description = "Nomad Workload Orchestrator";
        after = ["network-online.target" "consul.service"];
        wants = ["network-online.target"];
        requires = ["consul.service"];
        wantedBy = ["multi-user.target"];

        path = [pkgs.iproute2 pkgs.iptables];

        environment.NOMAD_ADDR = "http://127.0.0.1:${toString cfg.httpPort}";

        serviceConfig = {
          ExecStart = "${pkgs.nomad}/bin/nomad agent -config=/run/nomad/config.json";
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          Restart = "on-failure";
          RestartSec = "5s";
          StateDirectory = "nomad";
          RuntimeDirectory = "nomad";
          LimitNOFILE = 65536;
          LimitNPROC = "infinity";
          KillMode = "process";
          KillSignal = "SIGINT";
          TasksMax = "infinity";
          OOMScoreAdjust = -1000;
        };

        preStart = let
          injectEncrypt = lib.optionalString hasEncrypt ''
            KEY=$(cat ${cfg.encryptionKeyFile})
            ${pkgs.gnused}/bin/sed -i "s|__NOMAD_GOSSIP_KEY__|$KEY|" /run/nomad/config.json
          '';
          injectConsul = lib.optionalString hasConsulToken ''
            TOKEN=$(cat ${cfg.consul.tokenFile})
            ${pkgs.gnused}/bin/sed -i "s|__CONSUL_TOKEN__|$TOKEN|" /run/nomad/config.json
          '';
          injectVault = lib.optionalString hasVaultToken ''
            TOKEN=$(cat ${cfg.vault.tokenFile})
            ${pkgs.gnused}/bin/sed -i "s|__VAULT_TOKEN__|$TOKEN|" /run/nomad/config.json
          '';
        in ''
          cp ${configFile} /run/nomad/config.json
          ${injectEncrypt}
          ${injectConsul}
          ${injectVault}
          chmod 600 /run/nomad/config.json
        '';
      };

      psyclyx.nixos.network.ports.nomad = {
        tcp = [cfg.httpPort cfg.rpcPort cfg.serfPort];
        udp = [cfg.serfPort];
      };

      environment.systemPackages = [pkgs.nomad];
    };
}
