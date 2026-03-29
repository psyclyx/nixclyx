{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "consul"
  ];
  description = "Consul service discovery and DNS";
  options =
    { lib, ... }:
    {
      clusterNodes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Hostnames of all Consul server nodes.";
      };
      dataNetwork = lib.mkOption {
        type = lib.types.str;
        default = "infra";
        description = "Topology network for cluster and client traffic.";
      };
      datacenter = lib.mkOption {
        type = lib.types.str;
        default = "psyclyx";
      };
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/consul";
      };
      httpPort = lib.mkOption {
        type = lib.types.port;
        default = 8500;
      };
      dnsPort = lib.mkOption {
        type = lib.types.port;
        default = 8600;
      };
      serverPort = lib.mkOption {
        type = lib.types.port;
        default = 8300;
      };
      serfPort = lib.mkOption {
        type = lib.types.port;
        default = 8301;
      };
      encryptionKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file containing the gossip encryption key (from `consul keygen`).";
      };
      agentTokenFile = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Path to file containing this node's ACL agent token.";
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
      eg = config.psyclyx.egregore;
      hostname = config.psyclyx.nixos.host;

      bindAddr = eg.entities.${hostname}.host.addresses.${cfg.dataNetwork}.ipv4;
      otherNodes = builtins.filter (n: n != hostname) cfg.clusterNodes;
      retryJoinAddrs = map (n: eg.entities.${n}.host.addresses.${cfg.dataNetwork}.ipv4) otherNodes;

      hasEncrypt = cfg.encryptionKeyFile != null;
      hasAgentToken = cfg.agentTokenFile != null;

      configData = {
        server = true;
        node_name = hostname;
        datacenter = cfg.datacenter;
        data_dir = cfg.dataDir;
        bootstrap_expect = builtins.length cfg.clusterNodes;

        bind_addr = bindAddr;
        advertise_addr = bindAddr;
        client_addr = "127.0.0.1";

        retry_join = retryJoinAddrs;

        ports = {
          http = cfg.httpPort;
          dns = cfg.dnsPort;
          server = cfg.serverPort;
          serf_lan = cfg.serfPort;
        };

        dns_config = {
          allow_stale = true;
          node_ttl = "30s";
          service_ttl."*" = "15s";
        };

        ui_config.enabled = true;

        acl = {
          enabled = true;
          default_policy = "allow";
        } // lib.optionalAttrs hasAgentToken {
          tokens.agent = "__AGENT_TOKEN__";
        };

        performance.raft_multiplier = 1;
      } // lib.optionalAttrs hasEncrypt {
        encrypt = "__GOSSIP_KEY__";
      };

      configFile = pkgs.writeText "consul.json" (builtins.toJSON configData);
    in
    {
      users.users.consul = {
        isSystemUser = true;
        group = "consul";
      };
      users.groups.consul = {};

      systemd.services.consul = {
        description = "Consul Service Discovery";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];

        environment.CONSUL_HTTP_ADDR = "http://127.0.0.1:${toString cfg.httpPort}";

        serviceConfig = {
          User = "consul";
          Group = "consul";
          ExecStart = "${pkgs.consul}/bin/consul agent -config-file=/run/consul/config.json";
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          Restart = "on-failure";
          RestartSec = "5s";
          StateDirectory = "consul";
          RuntimeDirectory = "consul";
          LimitNOFILE = 65536;
          NoNewPrivileges = true;
          ProtectSystem = "full";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
        };

        preStart = let
          injectEncrypt = lib.optionalString hasEncrypt ''
            KEY=$(cat ${cfg.encryptionKeyFile})
            ${pkgs.gnused}/bin/sed -i "s|__GOSSIP_KEY__|$KEY|" /run/consul/config.json
          '';
          injectAgent = lib.optionalString hasAgentToken ''
            TOKEN=$(cat ${cfg.agentTokenFile})
            ${pkgs.gnused}/bin/sed -i "s|__AGENT_TOKEN__|$TOKEN|" /run/consul/config.json
          '';
        in ''
          cp ${configFile} /run/consul/config.json
          ${injectEncrypt}
          ${injectAgent}
          chmod 600 /run/consul/config.json
        '';
      };

      psyclyx.nixos.network.ports.consul = {
        tcp = [cfg.httpPort cfg.dnsPort cfg.serverPort cfg.serfPort (cfg.serfPort + 1)];
        udp = [cfg.dnsPort cfg.serfPort (cfg.serfPort + 1)];
      };

      environment.systemPackages = [pkgs.consul];
    };
}
