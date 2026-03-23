{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "k3s"
  ];
  description = "k3s Kubernetes cluster";
  options =
    { lib, ... }:
    {
      clusterNodes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Hostnames of all k3s server nodes.";
      };
      dataNetwork = lib.mkOption {
        type = lib.types.str;
        default = "infra";
        description = "Topology network for cluster and API traffic.";
      };
      apiPort = lib.mkOption {
        type = lib.types.port;
        default = 6443;
      };
      tokenFile = lib.mkOption {
        type = lib.types.str;
        description = "Path to file containing the k3s cluster join token.";
      };
      disableComponents = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = ["traefik" "servicelb"];
        description = "k3s components to disable.";
      };
      clusterCIDR = lib.mkOption {
        type = lib.types.str;
        default = "10.42.0.0/16";
      };
      serviceCIDR = lib.mkOption {
        type = lib.types.str;
        default = "10.43.0.0/16";
      };
      flannelBackend = lib.mkOption {
        type = lib.types.str;
        default = "none";
        description = "Flannel backend (set to 'none' when using an external CNI like Cilium).";
      };
      extraFlags = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Additional flags passed to k3s server.";
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

      # First node alphabetically is the init server
      initNode = fleet.leader cfg.clusterNodes;
      isInit = hostname == initNode;
      initAddr = fleet.hostAddress initNode cfg.dataNetwork;

      disableFlags = map (c: "--disable=${c}") cfg.disableComponents;

      serverFlags = [
        "--bind-address=${bindAddr}"
        "--advertise-address=${bindAddr}"
        "--node-ip=${bindAddr}"
        "--tls-san=${bindAddr}"
        "--tls-san=${fleet.groupVip "lab"}"
        "--cluster-cidr=${cfg.clusterCIDR}"
        "--service-cidr=${cfg.serviceCIDR}"
        "--flannel-backend=${cfg.flannelBackend}"
        "--disable-network-policy"
        "--kubelet-arg=node-ip=${bindAddr}"
      ] ++ disableFlags
        ++ (if isInit then ["--cluster-init"] else ["--server=https://${initAddr}:${toString cfg.apiPort}"])
        ++ cfg.extraFlags;

      flagStr = lib.concatStringsSep " \\\n  " serverFlags;
    in
    {
      # k3s needs these at runtime
      environment.systemPackages = with pkgs; [
        k3s
        kubectl
        kubernetes-helm
      ];

      # k3s manages its own containerd — don't conflict
      virtualisation.containerd.enable = lib.mkForce false;

      systemd.services.k3s = {
        description = "k3s Kubernetes Server";
        after = ["network-online.target" "firewall.service"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];

        path = [pkgs.k3s pkgs.iptables pkgs.iproute2 pkgs.coreutils];

        environment = {
          K3S_TOKEN_FILE = "%d/token";
          KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
        };

        serviceConfig = {
          Type = "notify";
          ExecStart = "${pkgs.k3s}/bin/k3s server ${flagStr}";
          KillMode = "process";
          Delegate = "yes";
          Restart = "on-failure";
          RestartSec = "10s";
          LimitNOFILE = 1048576;
          LimitNPROC = "infinity";
          LimitCORE = "infinity";
          TasksMax = "infinity";
          TimeoutStartSec = 0;
          LoadCredential = "token:${cfg.tokenFile}";
        };
      };

      # Symlink kubeconfig for convenience
      environment.etc."rancher/k3s/.keep".text = "";

      psyclyx.nixos.network.ports.k3s = {
        tcp = [cfg.apiPort 10250 10257 10259];
        udp = [];
      };
    };
}
