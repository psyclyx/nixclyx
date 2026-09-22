# Fleet projection: a Sodola node + the graph → the platform's options.
{ config, lib, egregore, egregorLib, deviceName, ... }:
let
  top = egregore;
  entity = top.entities.${deviceName};
  sw = entity.sodola;

  portDef = import ../egregore/lib/switch-port.nix { inherit lib egregorLib; };
  portType = portDef.portType;

  hwPortNames = map (n: "port${toString n}") (lib.range 1 9);

  pow2 = n: if n == 0 then 1 else 2 * pow2 (n - 1);

  mgmt     = top.entities.${sw.mgmtNetwork};
  mgmtVlan = mgmt.network.vlan;
  mgmtGw   = mgmt.attrs.gateway4;
  mgmtPLen = mgmt.attrs.prefixLen;

  maskOctet = bits:
    if bits >= 8 then 255
    else if bits <= 0 then 0
    else 256 - pow2 (8 - bits);
  mgmtMask = let p = mgmtPLen; in
    "${toString (maskOctet (lib.min p 8))}.${toString (maskOctet (lib.min (lib.max (p - 8) 0) 8))}.${toString (maskOctet (lib.min (lib.max (p - 16) 0) 8))}.${toString (maskOctet (lib.min (lib.max (p - 24) 0) 8))}";

  totalPorts = builtins.length hwPortNames;
  allPortNums = lib.range 1 totalPorts;

  portCfgN = n: sw.ports.${"port${toString n}"} or portDef.empty;

  switchVlans = let
    accessVlans = builtins.filter (v: v != null) (map (n: (portCfgN n).vlan) allPortNums);
    trunkVlans  = builtins.concatLists (map (n: (portCfgN n).vlans) allPortNums);
  in lib.sort builtins.lessThan (lib.unique ([1] ++ accessVlans ++ trunkVlans ++ [mgmtVlan]));

  vlanMembers = vlan: builtins.filter (n: let
    p = portCfgN n;
    mode = portType p;
    native = if p.vlan != null then p.vlan else 1;
  in (mode == "access" && p.vlan == vlan)
     || (mode == "trunk" && builtins.elem vlan p.vlans)
     || (n == totalPorts && mode != "unused" && native == vlan)
  ) allPortNums;

  mkPort = n: let
    p = portCfgN n;
    mode = portType p;
  in {
    mode = if mode == "access" then "access" else "trunk";
    nativeVlan = if mode == "access" then p.vlan else 1;
    speed = "auto";
  };
in {
  sodola.model = sw.model;
  sodola.password = sw.password;
  sodola.auth.username = sw.username;
  sodola.network = {
    ip = sw.addresses.mgmt.ipv4;
    netmask = mgmtMask;
    gateway = mgmtGw;
  };
  sodola.ports = map mkPort allPortNums;
  sodola.vlans = map (vlan: { id = vlan; members = vlanMembers vlan; name = ""; }) switchVlans;
  sodola.mgmtVlanHint = 1;
  sodola.igmpEnabled = false;
}
