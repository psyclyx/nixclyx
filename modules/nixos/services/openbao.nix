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
        default = "data";
        description = "Topology network name for Raft and API traffic.";
      };
      apiPort = lib.mkOption {
        type = lib.types.port;
        default = 8200;
        description = "Port for OpenBao API.";
      };
      clusterPort = lib.mkOption {
        type = lib.types.port;
        default = 8201;
        description = "Port for Raft cluster communication.";
      };
      storagePath = lib.mkOption {
        type = lib.types.str;
        default = "/var/lib/openbao";
        description = "Path for Raft storage data.";
      };
      uiEnable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the web UI.";
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
      unsealMethod = fleet.unsealMethod hostname;

      apiAddr = "http://${bindAddr}:${toString cfg.apiPort}";
      clusterAddr = "http://${bindAddr}:${toString cfg.clusterPort}";

      otherNodes = builtins.filter (n: n != hostname) cfg.clusterNodes;

      retryJoinStanzas = lib.concatMapStrings (node: let
        addr = fleet.hostAddress node cfg.dataNetwork;
      in ''
        retry_join {
          leader_api_addr = "http://${addr}:${toString cfg.apiPort}"
        }
      '') otherNodes;

      sealStanza =
        if unsealMethod == "tpm" then ''
          seal "pkcs11" {
            lib = "/run/current-system/sw/lib/libtpm2_pkcs11.so"
            slot = "0"
            pin = "env:BAO_TPM_PIN"
            key_label = "openbao-unseal"
            mechanism = "0x00001085"
            generate_key = "true"
          }
        ''
        else if unsealMethod == "transit" then
          let
            # Find a TPM-enabled peer to use as transit unseal source.
            tpmPeer = lib.findFirst
              (n: n != hostname && (fleet.hosts.${n}.hardware.tpm or false))
              (builtins.head otherNodes)
              cfg.clusterNodes;
            transitAddr = fleet.hostAddress tpmPeer cfg.dataNetwork;
          in ''
            seal "transit" {
              address = "http://${transitAddr}:${toString cfg.apiPort}"
              token = "" # Populated by operator/automation
              disable_renewal = "false"
              key_name = "autounseal"
              mount_path = "transit/"
            }
          ''
        else
          # Shamir — no seal stanza needed (default behavior).
          "";

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

        api_addr     = "${apiAddr}"
        cluster_addr = "${clusterAddr}"

        ${sealStanza}
      '';
    in
    {
      users.users.openbao = {
        isSystemUser = true;
        group = "openbao";
        home = cfg.storagePath;
        createHome = true;
      };
      users.groups.openbao = {};

      systemd.services.openbao = {
        description = "OpenBao Secrets Management";
        after = ["network-online.target"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];

        environment = {
          BAO_ADDR = "http://127.0.0.1:${toString cfg.apiPort}";
        };

        serviceConfig = {
          User = "openbao";
          Group = "openbao";
          ExecStart = "${pkgs.openbao}/bin/bao server -config=${configFile}";
          ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
          Restart = "on-failure";
          RestartSec = "5s";
          StateDirectory = "openbao";
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
      };

      # Firewall: allow API and cluster ports on the data network.
      networking.firewall.allowedTCPPorts = [cfg.apiPort cfg.clusterPort];
    };
}
