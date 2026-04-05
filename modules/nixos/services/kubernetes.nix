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
      eg = config.psyclyx.egregore;
      hostname = config.psyclyx.nixos.host;

      bindAddr = eg.entities.${hostname}.host.addresses.${cfg.dataNetwork}.ipv4;
      groupVip = eg.entities.lab.ha-group.vip.ipv4;

      # First node alphabetically is the init / CA authority
      initNode = builtins.head (builtins.sort builtins.lessThan cfg.clusterNodes);
      isInit = hostname == initNode;
      initAddr = eg.entities.${initNode}.host.addresses.${cfg.dataNetwork}.ipv4;

      # etcd endpoints from all cluster nodes
      etcdEndpoints = map (
        node: "https://${eg.entities.${node}.host.addresses.${cfg.etcdDataNetwork}.ipv4}:2379"
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
        easyCerts = false;

        apiserver = {
          advertiseAddress = bindAddr;
          bindAddress = bindAddr;
          securePort = 6443;
          serviceClusterIpRange = cfg.serviceCIDR;
          allowPrivileged = true; # required by Cilium

          etcd.servers = etcdEndpoints;
          etcd.caFile = "${config.services.kubernetes.secretsPath}/ca.pem";
          etcd.certFile = "${config.services.kubernetes.secretsPath}/kube-apiserver-etcd-client.pem";
          etcd.keyFile = "${config.services.kubernetes.secretsPath}/kube-apiserver-etcd-client-key.pem";

          clientCaFile = "${config.services.kubernetes.secretsPath}/ca.pem";
          tlsCertFile = "${config.services.kubernetes.secretsPath}/kube-apiserver.pem";
          tlsKeyFile = "${config.services.kubernetes.secretsPath}/kube-apiserver-key.pem";
          kubeletClientCaFile = "${config.services.kubernetes.secretsPath}/ca.pem";
          kubeletClientCertFile = "${config.services.kubernetes.secretsPath}/kube-apiserver-kubelet-client.pem";
          kubeletClientKeyFile = "${config.services.kubernetes.secretsPath}/kube-apiserver-kubelet-client-key.pem";
          serviceAccountSigningKeyFile = "${config.services.kubernetes.secretsPath}/service-account-key.pem";
          serviceAccountKeyFile = "${config.services.kubernetes.secretsPath}/service-account.pem";
          proxyClientCertFile = "${config.services.kubernetes.secretsPath}/kube-apiserver-proxy-client.pem";
          proxyClientKeyFile = "${config.services.kubernetes.secretsPath}/kube-apiserver-proxy-client-key.pem";

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
          kubeconfig = {
            caFile = "${config.services.kubernetes.secretsPath}/ca.pem";
            certFile = "${config.services.kubernetes.secretsPath}/kube-controller-manager-client.pem";
            keyFile = "${config.services.kubernetes.secretsPath}/kube-controller-manager-client-key.pem";
          };
          rootCaFile = "${config.services.kubernetes.secretsPath}/ca.pem";
          serviceAccountKeyFile = "${config.services.kubernetes.secretsPath}/service-account-key.pem";
          tlsCertFile = "${config.services.kubernetes.secretsPath}/kube-controller-manager.pem";
          tlsKeyFile = "${config.services.kubernetes.secretsPath}/kube-controller-manager-key.pem";
        };

        scheduler = {
          leaderElect = true;
          kubeconfig = {
            caFile = "${config.services.kubernetes.secretsPath}/ca.pem";
            certFile = "${config.services.kubernetes.secretsPath}/kube-scheduler-client.pem";
            keyFile = "${config.services.kubernetes.secretsPath}/kube-scheduler-client-key.pem";
          };
        };

        kubelet = {
          nodeIp = bindAddr;
          clientCaFile = "${config.services.kubernetes.secretsPath}/ca.pem";
          tlsCertFile = "${config.services.kubernetes.secretsPath}/kubelet.pem";
          tlsKeyFile = "${config.services.kubernetes.secretsPath}/kubelet-key.pem";
          kubeconfig = {
            caFile = "${config.services.kubernetes.secretsPath}/ca.pem";
            certFile = "${config.services.kubernetes.secretsPath}/kubelet-client.pem";
            keyFile = "${config.services.kubernetes.secretsPath}/kubelet-client-key.pem";
          };
          # No CNI config — Cilium installs its own after bootstrap
          cni.packages = [pkgs.cni-plugins];
          cni.config = [];
        };

        # Cilium replaces both kube-proxy and flannel
        proxy.enable = false;
        flannel.enable = false;

        # CoreDNS addon — uses the NixOS module's built-in
        addons.dns.enable = true;

        pki.caCertPathPrefix = "${config.services.kubernetes.secretsPath}/ca";

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

      # ── containerd v2 needs config version 3 + unpack platform ──
      virtualisation.containerd.settings = {
        version = lib.mkForce 3;
        plugins."io.containerd.transfer.v1.local".unpack_config = [
          { platform = "linux/amd64"; snapshotter = "overlayfs"; }
        ];
      };

      # ── CLI tools on the hosts ─────────��─────────────────────
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
