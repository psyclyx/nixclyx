{
  path = [
    "psyclyx"
    "nixos"
    "services"
    "kubernetes"
  ];
  description = "Kubernetes cluster (full control plane + worker)";
  options =
    { lib, ... }:
    {
      clusterNodes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        description = "Hostnames of all Kubernetes control-plane nodes.";
      };
      dataNetwork = lib.mkOption {
        type = lib.types.str;
        default = "infra";
        description = "Topology network for API server and inter-component traffic.";
      };
      etcdDataNetwork = lib.mkOption {
        type = lib.types.str;
        default = "infra";
        description = "Topology network where etcd listens.";
      };
      podCIDR = lib.mkOption {
        type = lib.types.str;
        default = "10.42.0.0/16";
        description = "CIDR range for pod IPs.";
      };
      serviceCIDR = lib.mkOption {
        type = lib.types.str;
        default = "10.43.0.0/16";
        description = "CIDR range for cluster service IPs.";
      };
      addons = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
        description = "Additional manifests for the addon manager.";
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
      groupVip = fleet.groupVip "lab";

      # First node alphabetically is the init / CA authority
      initNode = fleet.leader cfg.clusterNodes;
      isInit = hostname == initNode;
      initAddr = fleet.hostAddress initNode cfg.dataNetwork;

      # etcd endpoints from all cluster nodes
      etcdEndpoints = map (
        node: "https://${fleet.hostAddress node cfg.etcdDataNetwork}:2379"
      ) cfg.clusterNodes;

      # Namespace addon manifests
      mkNamespace = name: {
        apiVersion = "v1";
        kind = "Namespace";
        metadata = {
          name = name;
          labels.env = name;
        };
      };
    in
    {
      # ── NixOS Kubernetes module ───────────────────────────────
      services.kubernetes = {
        roles = ["master" "node"];
        package = pkgs.kubernetes;
        masterAddress = groupVip;
        apiserverAddress = "https://${groupVip}:6443";
        clusterCidr = cfg.podCIDR;
        easyCerts = true;

        apiserver = {
          advertiseAddress = bindAddr;
          securePort = 6443;
          serviceClusterIpRange = cfg.serviceCIDR;
          allowPrivileged = true; # required by Cilium

          etcd.servers = etcdEndpoints;

          extraSANs = [
            bindAddr
            groupVip
            hostname
            "${hostname}.psyclyx.net"
          ];
        };

        controllerManager = {
          leaderElect = true;
          allocateNodeCIDRs = true;
          clusterCidr = cfg.podCIDR;
        };

        scheduler.leaderElect = true;

        kubelet = {
          nodeIp = bindAddr;
          # No CNI config — Cilium installs its own after bootstrap
          cni.packages = [pkgs.cni-plugins];
          cni.config = [];
        };

        # Cilium replaces both kube-proxy and flannel
        proxy.enable = false;
        flannel.enable = false;

        # CoreDNS addon — uses the NixOS module's built-in
        addons.dns.enable = true;

        # PKI: leader generates the CA, others bootstrap trust
        pki = {
          genCfsslCACert = isInit;
          genCfsslAPICerts = isInit;
          pkiTrustOnBootstrap = true;

          # Point non-init nodes to the leader for cert bootstrapping
          caCertPathPrefix =
            if isInit
            then "${config.services.cfssl.dataDir}/ca"
            else "${config.services.kubernetes.secretsPath}/ca";
        };

        addonManager = {
          enable = true;
          addons =
            {
              stage-ns = mkNamespace "stage";
              prod-ns = mkNamespace "prod";
            }
            // cfg.addons;
        };
      };

      # ── CFSSL CA server (leader only) ────────────────────────
      # Non-init nodes connect to the leader's CFSSL to bootstrap
      # their certificates (pkiTrustOnBootstrap handles TOFU).
      services.cfssl = lib.mkIf (!isInit) {
        address = initAddr;
      };

      # ── CLI tools on the hosts ───────────────────────────────
      environment.systemPackages = [
        pkgs.kubernetes
        pkgs.kubectl
        pkgs.kubernetes-helm
      ];

      # ── kubeconfig convenience ───────────────────────────────
      environment.variables.KUBECONFIG = "/etc/kubernetes/cluster-admin.kubeconfig";

      # ── Port registry ────────────────────────────────────────
      psyclyx.nixos.network.ports.kubernetes = {
        tcp = [
          6443 # API server
          10250 # kubelet
          10257 # controller-manager
          10259 # scheduler
        ];
      };
    };
}
