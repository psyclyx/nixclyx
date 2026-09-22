# Fleet projection: a SwOS node + the graph → the platform's options.
{ config, lib, egregore, egregorLib, deviceName, ... }:
let
  top = egregore;
  entity = top.entities.${deviceName};
  name = deviceName;
  sw = entity.swos;

  portDef = import ../egregore/lib/switch-port.nix { inherit lib egregorLib; };
  portType = portDef.portType;
  portLabel = portDef.portLabel;

  # CSS326: 24 copper + 2 SFP+. Port order is the SwOS index order.
  hwPortNames =
    (map (i: "ether${toString i}") (lib.range 1 24))
    ++ ["sfp-sfpplus1" "sfp-sfpplus2"];

  identity = if sw.identity != null then sw.identity else name;
  mgmtVlan = top.entities.${sw.mgmtNetwork}.network.vlan;
  mgmtIp = sw.addresses.mgmt.ipv4;

  totalPorts = builtins.length hwPortNames;
  allIndices = lib.range 0 (totalPorts - 1);
  allPorts1 = lib.range 1 totalPorts;
  portName = idx: builtins.elemAt hwPortNames idx;
  cfgAt = idx: let n = portName idx; in sw.ports.${n} or portDef.empty;
  modeAt = idx: portType (cfgAt idx);

  switchVlans = let
    accessVlans = builtins.filter (v: v != null) (map (i: (cfgAt i).vlan) allIndices);
    trunkVlans  = builtins.concatLists (map (i: (cfgAt i).vlans) allIndices);
  in lib.sort builtins.lessThan (lib.unique (accessVlans ++ trunkVlans ++ [mgmtVlan]));

  vlanMembers = vlan: builtins.filter (n: let
    idx = n - 1;
    p = cfgAt idx;
    mode = modeAt idx;
  in (mode == "access" && p.vlan == vlan)
     || (mode == "trunk" && builtins.elem vlan p.vlans)
  ) allPorts1;

  mkPort = idx: let
    p = cfgAt idx;
    mode = modeAt idx;
    isEnabled = mode != "unused";
    label = if isEnabled then builtins.substring 0 16 (portLabel p) else "";
  in {
    autoNegotiate = true;
    blocked = false;
    cableMode = 0;
    defaultVid = if mode == "access" then p.vlan else 1;
    duplex = true;
    enabled = isEnabled;
    flowControlRx = false;
    flowControlTx = true;
    forwardMulticast = true;
    forwardTo = builtins.filter (n: n != (idx + 1)) allPorts1;
    ingressRate = 0;
    inputMirror = false;
    lacpGroup = p.lacpGroup;
    lacpMode = if p.lacpGroup != 0 then 1 else 0;
    macLock = false;
    macLockFilter = false;
    name = label;
    outputMirror = false;
    qosType = 0;
    sfp = idx >= 24;
    sourceUnknown = false;
    speed = 0;
    stormRate = 100;
    vlanMode = if isEnabled then 2 else 0;
    vlanReceive = 0;
  };
in {
  swos.identity = identity;
  swos.username = sw.username;
  swos.password = sw.password;
  swos.ports = map mkPort allIndices;
  swos.vlans = map (vlan: {
    id = vlan;
    igmp = false;
    learning = true;
    members = vlanMembers vlan;
    mirror = false;
    name = "";
    portIsolation = false;
  }) switchVlans;
  swos.system = {
    adminVlan = mgmtVlan;
    allPorts = allPorts1;
    allowFromAllAddresses = false;
    allowFromAllMgmt = false;
    autoInfo = true;
    discovery = true;
    dropTagged = builtins.filter (n: modeAt (n - 1) != "trunk") allPorts1;
    frameSizeCheck = false;
    identity = identity;
    igmpFlood = false;
    igmpQuery = true;
    igmpSnooping = false;
    igmpVlanExclusive = true;
    ip = mgmtIp;
    ipType = 1;
    ivl = false;
    management = true;
    poe = false;
    portDiscovery = allPorts1;
    stpCostMode = 0;
    stpPriority = 32768;
    watchdog = true;
  };
  swos.snmp = { community = "public"; contact = ""; enabled = true; location = ""; };
  swos.rstp = { enabledPorts = allPorts1; };
  swos.mirror = { targetPort = 1; };
}
