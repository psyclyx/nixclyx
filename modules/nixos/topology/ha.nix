# Derives keepalived (VRRP VIP) and haproxy (load balancer) configuration
# from topology haGroups for hosts that are members of an HA group.
{
  config,
  lib,
  pkgs,
  ...
}: let
  topo = config.psyclyx.topology;
  dt = topo.enriched;
  conventions = topo.conventions;
  hostname = config.psyclyx.nixos.host;
  hostDef = topo.hosts.${hostname} or null;
  labIdx = if hostDef != null then hostDef.labIndex else null;

  # Find all haGroups this host is a member of.
  myGroups = lib.filterAttrs
    (_: group: builtins.elem hostname group.members)
    topo.haGroups;

  hasGroups = myGroups != {};

  # Derive VIP address for a group.
  groupVip = group: let
    net = dt.networks.${group.network};
  in "${net.prefix}.${toString group.vipOffset}";

  # Derive this host's address on the group's network.
  hostAddr = group: let
    net = dt.networks.${group.network};
  in "${net.prefix}.${toString (conventions.hostBaseOffset + labIdx)}";

  # Derive the network interface for a group.
  groupIface = group: let
    ifaceDef = hostDef.interfaces.${group.network} or null;
  in
    if ifaceDef != null && ifaceDef.bond != null
    then ifaceDef.bond
    else if ifaceDef != null && ifaceDef.device != null
    then ifaceDef.device
    else group.network;

  # Collect unique VIPs across all groups (for keepalived).
  # Key by "network-vipOffset" to deduplicate.
  uniqueVips = lib.unique (lib.mapAttrsToList (_: group: {
    vip = groupVip group;
    iface = groupIface group;
    vrid = group.vipOffset; # must be 1-255
    priority = 100 - labIdx; # lab-1=99, lab-2=98, etc.
  }) myGroups);

  # Build haproxy config from all groups.
  haproxyConfig = let
    metricsAddr = hostAddr (builtins.head (lib.attrValues myGroups));

    globalSection = ''
      global
        log stdout local0
        maxconn 4096
        stats socket /run/haproxy/admin.sock mode 660 level admin

      defaults
        log global
        option dontlognull
        timeout connect 5s
        timeout client 30s
        timeout server 30s
        retries 3
    '';

    statsSection = ''
      frontend stats
        bind ${metricsAddr}:9101
        mode http
        http-request use-service prometheus-exporter if { path /metrics }
        stats enable
        stats uri /stats
        stats refresh 10s
    '';

    mkFrontendBackend = groupName: group: svcName: svc: let
      vip = groupVip group;
      frontendPort = svc.port;
      backendPort = if svc.backendPort != null then svc.backendPort else svc.port;
      name = "${groupName}-${svcName}";
      memberAddrs = map (member: let
        idx = topo.hosts.${member}.labIndex;
        net = dt.networks.${group.network};
      in {
        addr = "${net.prefix}.${toString (conventions.hostBaseOffset + idx)}";
        inherit member;
      }) group.members;
      checkUri = if svc.check != null then svc.check else "/";
      checkDirective =
        if svc.check != null || svc.mode == "http"
        then ''
        option httpchk
        http-check send meth GET uri ${checkUri} ver HTTP/1.1 hdr Host localhost
        http-check expect status 200''
        else "";
      checkPortSuffix =
        if svc.checkPort != null
        then " port ${toString svc.checkPort}"
        else "";
    in ''

      frontend ft_${name}
        bind ${vip}:${toString frontendPort}
        mode ${svc.mode}
        default_backend bk_${name}

      backend bk_${name}
        mode ${svc.mode}
        balance roundrobin
        ${checkDirective}
    '' + lib.concatMapStringsSep "\n" (m:
      "    server ${m.member} ${m.addr}:${toString backendPort} check${checkPortSuffix} inter 5s fall 3 rise 2"
    ) memberAddrs + "\n";

    serviceSections = lib.concatStringsSep "" (lib.flatten (
      lib.mapAttrsToList (groupName: group:
        lib.mapAttrsToList (svcName: svc:
          mkFrontendBackend groupName group svcName svc
        ) group.services
      ) myGroups
    ));
  in
    globalSection + statsSection + serviceSections;

  # Collect all service ports for firewall.
  allServicePorts = lib.unique (lib.flatten (
    lib.mapAttrsToList (_: group:
      lib.mapAttrsToList (_: svc: svc.port) group.services
    ) myGroups
  ));
in {
  config = lib.mkIf (hasGroups && labIdx != null) {
    # Allow haproxy to bind the VIP before keepalived assigns it.
    boot.kernel.sysctl."net.ipv4.ip_nonlocal_bind" = 1;

    services.keepalived = {
      enable = true;
      vrrpInstances = builtins.listToAttrs (lib.imap0 (i: vip:
        lib.nameValuePair "VI_${toString (i + 1)}" {
          interface = vip.iface;
          state = "BACKUP";
          noPreempt = true;
          virtualRouterId = vip.vrid;
          priority = vip.priority;
          virtualIps = [
            { addr = "${vip.vip}/24"; }
          ];
        }
      ) uniqueVips);
    };

    services.haproxy = {
      enable = true;
      config = haproxyConfig;
    };

    systemd.services.haproxy = {
      after = ["network-online.target"];
      wants = ["network-online.target"];
      serviceConfig.RuntimeDirectory = "haproxy";
    };

    # Firewall: VRRP protocol + HA service ports + stats port.
    networking.firewall.extraCommands = ''
      iptables -A nixos-fw -p vrrp -j nixos-fw-accept
    '';
    networking.firewall.extraStopCommands = ''
      iptables -D nixos-fw -p vrrp -j nixos-fw-accept 2>/dev/null || true
    '';
    psyclyx.nixos.network.ports.haproxy = allServicePorts ++ [9101];
  };
}
