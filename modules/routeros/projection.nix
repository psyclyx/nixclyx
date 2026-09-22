# Fleet projection: a RouterOS node + the graph → the platform's options.
#
# This is the egregore-aware half of RouterOS. It reads one entity and
# the fleet graph and sets `routeros.*`; the platform (lib/platform/
# routeros) owns the schema and the render. The split is deliberate: the
# mechanism lives in `lib/`, the fleet's choices live here.
{ config, lib, egregore, egregorLib, deviceName, ... }:
let
  top = egregore;
  entity = top.entities.${deviceName};
  name = deviceName;
  sw = entity.routeros;

  portDef = import ../egregore/lib/switch-port.nix { inherit lib egregorLib; };
  portType = portDef.portType;
  portLabel = portDef.portLabel;

  # Hardware port lists for known models.
  modelPorts = {
    "CRS326-24S+2Q+RM" =
      (map (i: "sfp-sfpplus${toString i}") (lib.range 1 24))
      ++ (lib.concatMap (q:
        map (s: "qsfpplus${toString q}-${toString s}") (lib.range 1 4)
      ) (lib.range 1 2));
    "CRS305-1G-4S+IN" =
      ["ether1"] ++ map (i: "sfp-sfpplus${toString i}") (lib.range 1 4);
  };

  mgmt = top.entities.${sw.mgmtNetwork};
  mgmtVlan = mgmt.network.vlan;
  mgmtIp = sw.addresses.${sw.mgmtNetwork}.ipv4;
  identity = if sw.identity != null then sw.identity else name;
  adminKeys = top.conventions.adminSshKeys or [];

  myRoutes = map (n: top.entities.${n}) (entity.refsIn.on or []);
  routesFor = family: builtins.filter (r: r.attrs.family == family) myRoutes;
  mkRouteRow = r: { inherit (r.attrs) dst gateway disabled; inherit (r.route) comment; };
  defaultDst = family: if family == "ipv6" then "::/0" else "0.0.0.0/0";
  defaultRoute = family:
    lib.findFirst (r: r.attrs.dst == defaultDst family) null (routesFor family);

  egressNet = let d = defaultRoute "ipv4"; in if d == null then null else d.refs.over;

  dhcpServerAddr = netName: let
    serverName = (top.entities.${netName}).attrs.dnsRef;
    server = top.entities.${serverName} or null;
  in
    if serverName == null || server == null || egressNet == null then null
    else ((server.attrs.addresses or {}).${egressNet} or {}).ipv4 or null;

  addressNetworks = lib.attrNames sw.addresses;

  myDelegation = lib.findFirst
    (d: (d.refs.to or null) == name) null
    (builtins.filter (e: e.type == "prefix-delegation")
      (builtins.attrValues (top.entities or {})));
  pdPool = "delegated";
  pdNetworks = lib.intersectLists addressNetworks (entity.refsIn.gateway6 or []);

  internalV4 = top.conventions.internalPrefixes or [];
  internalV6 =
    lib.optional ((top.ipv6UlaPrefix or "") != "") "${top.ipv6UlaPrefix}::/48";

  wanDenied = builtins.filter (netName: let
    zone = (top.entities.${netName}).attrs.zone or "";
    policy = (top.policy.${zone} or {}).wan or null;
  in zone != "" && policy != "accept") addressNetworks;

  switchRules = lib.concatMap (netName: let
    vlan = (top.entities.${netName}).network.vlan;
    rule = extra: { switch = sw.primarySwitchChip; vlanId = vlan; } // extra;
  in
    lib.optionals (vlan != null && sw.primarySwitchChip != null) (
      map (p: rule { dstAddress = p; comment = "${netName}: internal v4"; }) internalV4
      ++ map (p: rule { dstAddress6 = p; comment = "${netName}: internal v6"; }) internalV6
      ++ [ (rule { newDstPorts = ""; comment = "${netName}: no route off-site"; }) ]
    )) wanDenied;

  maxNetMtu = lib.foldl' lib.max 1500
    (map (n: top.entities.${n}.network.mtu or 1500) addressNetworks);
  portL2mtu = if maxNetMtu > 1500 then maxNetMtu + 4 else null;

  portCfg = pname: sw.ports.${pname} or portDef.empty;

  bondSlaveMap = lib.foldlAttrs (acc: bondName: bond:
    builtins.foldl' (a: slave: a // { ${slave} = bondName; }) acc bond.slaves
  ) {} sw.bonds;

  bridgeIface = pname:
    if bondSlaveMap ? ${pname} then bondSlaveMap.${pname} else pname;

  hwPorts = modelPorts.${sw.model} or (builtins.attrNames sw.ports);
  activePorts = builtins.filter (n: portType (portCfg n) != "unused") hwPorts;
  bridgeInterfaces = lib.unique (map bridgeIface activePorts);

  accessPorts = builtins.filter (n: portType (portCfg n) == "access") hwPorts;
  trunkPorts  = builtins.filter (n: portType (portCfg n) == "trunk") hwPorts;
  usedVlans = let
    aVlans = map (n: (portCfg n).vlan) accessPorts;
    tVlans = builtins.concatLists (map (n: (portCfg n).vlans) trunkPorts);
  in lib.sort builtins.lessThan (lib.unique (aVlans ++ tVlans ++ [mgmtVlan]));

  sviVlans = map (netName: (top.entities.${netName}).network.vlan) addressNetworks;

  accessByVlan = let
    pairs = map (pname: { vlan = (portCfg pname).vlan; port = pname; }) accessPorts;
  in builtins.groupBy (p: toString p.vlan) pairs;

  trunkCarriesVlan = pname: vlan: builtins.elem vlan (portCfg pname).vlans;

  vlanEntry = vlan: let
    vStr = toString vlan;
    untagged = if accessByVlan ? ${vStr}
      then lib.unique (map (p: bridgeIface p.port) accessByVlan.${vStr})
      else [];
    tIfaces = lib.unique (builtins.filter (iface:
      builtins.any (tp: bridgeIface tp == iface && trunkCarriesVlan tp vlan) trunkPorts
    ) (map bridgeIface trunkPorts));
    tagged = tIfaces ++ lib.optional (builtins.elem vlan sviVlans) "bridge1";
  in {
    vlanIds = vStr;
    inherit tagged untagged;
  };
in {
  routeros.model = sw.model;
  routeros.identity = identity;
  routeros.timezone = sw.timezone;

  routeros.system = {
    dnsServers = [mgmt.attrs.gateway4];
    l3HwOffload = sw.l3HwOffload;
    sshKeys = map (key: { inherit key; user = sw.sshUser; }) adminKeys;
    snmp.enable = true;
  };

  routeros.ethernetSwitches = lib.optional (sw.primarySwitchChip != null) {
    name = sw.primarySwitchChip;
    l3HwOffload = sw.l3HwOffload;
  };

  routeros.l3hwSettings = {
    ipv6Hw = sw.l3HwSettings.ipv6Hw;
    icmpReplyOnError = sw.l3HwSettings.icmpReplyOnError;
  };

  routeros.interfaces = map (pname: {
    name = pname;
    enabled = true;
  } // lib.optionalAttrs (portL2mtu != null) {
    l2mtu = portL2mtu;
  }) activePorts;

  routeros.bonds = lib.mapAttrsToList (bondName: bond: {
    name = bondName;
    mode = bond.mode;
    slaves = bond.slaves;
    lacpMode = bond.lacpMode;
    comment = bond.comment;
  }) sw.bonds;

  routeros.bridge = {
    name = "bridge1";
    protocolMode = "none";
    igmpSnooping = sw.bridge.multicast.snooping;
    multicastQuerier = sw.bridge.multicast.querier;
    multicastRouter = sw.bridge.multicast.router;
    igmpVersion = sw.bridge.multicast.igmpVersion;
    mldVersion = sw.bridge.multicast.mldVersion;
    vlanFiltering = true;
    ports = map (iface: let
      portName = if sw.bonds ? ${iface}
        then builtins.head sw.bonds.${iface}.slaves
        else iface;
      p = portCfg portName;
      mode = portType p;
    in {
      interface = iface;
      pvid = if mode == "access" then p.vlan else 1;
      comment =
        if sw.bonds ? ${iface} then
          if sw.bonds.${iface}.comment != null then sw.bonds.${iface}.comment else iface
        else portLabel p;
    }) bridgeInterfaces;
    vlans = map vlanEntry usedVlans;
  };

  routeros.vlanInterfaces = map (netName: let
    net = top.entities.${netName};
  in {
    interface = "bridge1";
    name = "vlan${toString net.network.vlan}";
    vlanId = net.network.vlan;
    mtu = net.network.mtu;
  }) addressNetworks;

  routeros.addresses = map (netName: let
    net = top.entities.${netName};
  in {
    address = "${sw.addresses.${netName}.ipv4}/${toString net.attrs.prefixLen}";
    interface = "vlan${toString net.network.vlan}";
    network = net.attrs.network4;
  }) addressNetworks;

  routeros.ipv6Addresses = lib.flip lib.concatMap addressNetworks (netName: let
    net = top.entities.${netName};
    v6 = sw.addresses.${netName}.ipv6 or null;
    iface = "vlan${toString net.network.vlan}";
  in
    lib.optional (v6 != null) { address = "${v6}/64"; interface = iface; }
    ++ lib.optional (myDelegation != null && builtins.elem netName pdNetworks) {
      fromPool = pdPool;
      interface = iface;
      advertise = true;
    });

  routeros.dhcpRelays = lib.flip lib.concatMap addressNetworks (netName: let
    net = top.entities.${netName};
    server = dhcpServerAddr netName;
    localAddr = sw.addresses.${netName}.ipv4 or null;
  in lib.optional
    (net.network.dhcpRelay && server != null && localAddr != null)
    {
      name = "relay-${netName}";
      interface = "vlan${toString net.network.vlan}";
      dhcpServer = [ server ];
      localAddress = localAddr;
      disabled = false;
    });

  routeros.ipv6Settings.forwarding = sw.ipv6Forward;

  routeros.ipv6Nd = lib.optionals (defaultRoute "ipv6" == null)
    (map (netName: {
      interface = "vlan${toString top.entities.${netName}.network.vlan}";
      raLifetime = "none";
    }) (builtins.filter
      (n: (sw.addresses.${n}.ipv6 or null) != null)
      addressNetworks));

  routeros.ipv6DhcpClients = lib.optional (myDelegation != null) {
    interface = "vlan${toString (top.entities.${myDelegation.refs.over}).network.vlan}";
    request = "prefix";
    poolName = pdPool;
    poolPrefixLength = 64;
    addDefaultRoute = false;
  };

  routeros.switchRules = switchRules;
  routeros.routes = map mkRouteRow (routesFor "ipv4");
  routeros.ipv6Routes = map mkRouteRow (routesFor "ipv6");
}
