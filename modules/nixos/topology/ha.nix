{
  config,
  lib,
  pkgs,
  ...
}: let
  topo = config.psyclyx.topology;
  fleet = config.psyclyx.fleet;
  hostname = config.psyclyx.nixos.host;

  myGroups = lib.filterAttrs
    (_: group: builtins.elem hostname group.members)
    topo.haGroups;

  hasGroups = myGroups != {};

  uniqueVips = lib.unique (lib.mapAttrsToList (groupName: group: {
    vip = fleet.groupVip groupName;
    iface = fleet.hostInterface hostname group.network;
    vrid = fleet.groupVrid groupName;
    priority = fleet.memberPriority groupName hostname;
    prefixLen = fleet.networkPrefixLen group.network;
  }) myGroups);

  haproxyConfig = let
    metricsAddr = fleet.hostAddress hostname (builtins.head (lib.attrValues myGroups)).network;

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
      vip = fleet.groupVip groupName;
      frontendPort = svc.port;
      backendPort = if svc.backendPort != null then svc.backendPort else svc.port;
      name = "${groupName}-${svcName}";
      memberAddrs = map (member: {
        addr = fleet.hostAddress member group.network;
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
      sslSuffix =
        if svc.checkSsl
        then " ssl verify none check-ssl"
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
      "    server ${m.member} ${m.addr}:${toString backendPort} check${checkPortSuffix}${sslSuffix} inter 5s fall 3 rise 2"
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

  allServicePorts = lib.unique (lib.flatten (
    lib.mapAttrsToList (_: group:
      lib.mapAttrsToList (_: svc: svc.port) group.services
    ) myGroups
  ));
in {
  config = lib.mkIf hasGroups {
    # haproxy needs to bind the VIP before keepalived assigns it
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
            { addr = "${vip.vip}/${toString vip.prefixLen}"; }
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

    psyclyx.nixos.network.ports.haproxy = allServicePorts ++ [9101];
  };
}
