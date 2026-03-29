{config, lib, pkgs, ...}: let
  eg = config.psyclyx.egregore;
  hostname = config.psyclyx.nixos.host;

  haGroups = lib.filterAttrs (_: e:
    e.type == "ha-group" && builtins.elem hostname e.ha-group.members
  ) eg.entities;

  hasGroups = haGroups != {};

  me = eg.entities.${hostname};

  uniqueVips = lib.unique (lib.mapAttrsToList (groupName: g: let
    ha = g.ha-group;
    net = eg.entities.${ha.network};
    idx = lib.lists.findFirstIndex (m: m == hostname)
      (throw "${hostname} is not a member of group ${groupName}")
      ha.members;
  in {
    vip = ha.vip.ipv4;
    iface = me.host.interfaces.${ha.network}.device;
    vrid = ha.vrid;
    priority = 100 - (idx + 1);
    prefixLen = net.attrs.prefixLen;
  }) haGroups);

  haproxyConfig = let
    firstGroup = builtins.head (lib.attrValues haGroups);
    metricsAddr = me.host.addresses.${firstGroup.ha-group.network}.ipv4;

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

    mkFrontendBackend = groupName: g: svcName: svc: let
      ha = g.ha-group;
      vip = ha.vip.ipv4;
      frontendPort = svc.port;
      backendPort = if svc.backendPort != null then svc.backendPort else svc.port;
      name = "${groupName}-${svcName}";
      memberAddrs = map (member: {
        addr = eg.entities.${member}.host.addresses.${ha.network}.ipv4;
        inherit member;
      }) ha.members;
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
      lib.mapAttrsToList (groupName: g:
        lib.mapAttrsToList (svcName: svc:
          mkFrontendBackend groupName g svcName svc
        ) g.ha-group.services
      ) haGroups
    ));
  in
    globalSection + statsSection + serviceSections;

  allServicePorts = lib.unique (lib.flatten (
    lib.mapAttrsToList (_: g:
      lib.mapAttrsToList (_: svc: svc.port) g.ha-group.services
    ) haGroups
  ));
in {
  config = lib.mkIf hasGroups {
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
