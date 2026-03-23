{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "openbao"
  ];
  description = "OpenBao secrets management with integrated Raft storage";
  options =
    { lib, ... }:
    {
      clusterNodes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Hostnames of all nodes in the OpenBao cluster.";
      };
      dataNetwork = lib.mkOption {
        type = lib.types.str;
        default = "infra";
        description = "Network for Raft and API traffic.";
      };
      apiPort = lib.mkOption {
        type = lib.types.port;
        default = 8200;
      };
      clusterPort = lib.mkOption {
        type = lib.types.port;
        default = 8201;
      };
      storagePath = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/openbao";
      };
      uiEnable = lib.mkOption {
        type = lib.types.bool;
        default = true;
      };
      transitAddress = lib.mkOption {
        type = lib.types.str;
        description = "Address of the transit seal provider (e.g. http://10.0.25.1:8200).";
      };
      transitTokenFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to file containing the transit auto-unseal token.";
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

      retryJoinStanzas = lib.concatMapStrings (node: ''
        retry_join {
          leader_api_addr = "http://${fleet.hostAddress node cfg.dataNetwork}:${toString cfg.apiPort}"
        }
      '') otherNodes;

      configFile = pkgs.writeText "openbao.hcl" ''
        ui = ${lib.boolToString cfg.uiEnable}

        listener "tcp" {
          address       = "${bindAddr}:${toString cfg.apiPort}"
          tls_disable   = "true"
        }

        listener "tcp" {
          address       = "127.0.0.1:${toString cfg.apiPort}"
          tls_disable   = "true"
        }

        storage "raft" {
          path    = "${cfg.storagePath}"
          node_id = "${hostname}"

          ${retryJoinStanzas}
        }

        api_addr     = "http://${bindAddr}:${toString cfg.apiPort}"
        cluster_addr = "http://${bindAddr}:${toString cfg.clusterPort}"

        seal "transit" {
          address         = "${cfg.transitAddress}"
          token           = "__TRANSIT_TOKEN__"
          disable_renewal = "false"
          key_name        = "autounseal"
          mount_path      = "transit/"
        }
      '';
    in
    {
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

        serviceConfig = {
          User = "openbao";
          Group = "openbao";
          ExecStart = "${pkgs.openbao}/bin/bao server -config=/run/openbao/config.hcl";
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          Restart = "on-failure";
          RestartSec = "10s";
          StartLimitIntervalSec = 0;
          StateDirectory = "openbao";
          RuntimeDirectory = "openbao";
          LimitNOFILE = 65536;
          LimitMEMLOCK = "infinity";
          AmbientCapabilities = "CAP_IPC_LOCK";
          CapabilityBoundingSet = "CAP_SYSLOG CAP_IPC_LOCK";
          NoNewPrivileges = true;
          ProtectSystem = "full";
          ProtectHome = true;
          PrivateTmp = true;
          PrivateDevices = true;
        };

        # Inject transit token into config at runtime (keeps token out of nix store)
        preStart = ''
          TOKEN=$(cat ${cfg.transitTokenFile})
          ${pkgs.gnused}/bin/sed "s|__TRANSIT_TOKEN__|$TOKEN|" ${configFile} > /run/openbao/config.hcl
          chmod 600 /run/openbao/config.hcl
        '';
      };

      networking.firewall.allowedTCPPorts = [cfg.apiPort cfg.clusterPort];
    };
}
