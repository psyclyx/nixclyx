# SwOS platform — render `config.swos` to a `.swb` backup.
{ config, lib, pkgs, swosLib, ... }:
let
  s = config.swos;

  json = {
    ports = map (p: {
      auto_negotiate = p.autoNegotiate;
      blocked = p.blocked;
      cable_mode = p.cableMode;
      default_vid = p.defaultVid;
      duplex = p.duplex;
      enabled = p.enabled;
      flow_control_rx = p.flowControlRx;
      flow_control_tx = p.flowControlTx;
      forward_multicast = p.forwardMulticast;
      forward_to = p.forwardTo;
      ingress_rate = p.ingressRate;
      input_mirror = p.inputMirror;
      lacp_group = p.lacpGroup;
      lacp_mode = p.lacpMode;
      mac_lock = p.macLock;
      mac_lock_filter = p.macLockFilter;
      name = p.name;
      output_mirror = p.outputMirror;
      qos_type = p.qosType;
      sfp = p.sfp;
      source_unknown = p.sourceUnknown;
      speed = p.speed;
      storm_rate = p.stormRate;
      vlan_mode = p.vlanMode;
      vlan_receive = p.vlanReceive;
    }) s.ports;
    vlans = map (v: {
      id = v.id;
      igmp = v.igmp;
      learning = v.learning;
      members = v.members;
      mirror = v.mirror;
      name = v.name;
      port_isolation = v.portIsolation;
    }) s.vlans;
    system = {
      admin_vlan = s.system.adminVlan;
      all_ports = s.system.allPorts;
      allow_from_all_addresses = s.system.allowFromAllAddresses;
      allow_from_all_mgmt = s.system.allowFromAllMgmt;
      auto_info = s.system.autoInfo;
      discovery = s.system.discovery;
      drop_tagged = s.system.dropTagged;
      frame_size_check = s.system.frameSizeCheck;
      identity = s.system.identity;
      igmp_flood = s.system.igmpFlood;
      igmp_query = s.system.igmpQuery;
      igmp_snooping = s.system.igmpSnooping;
      igmp_vlan_exclusive = s.system.igmpVlanExclusive;
      ip = s.system.ip;
      ip_type = s.system.ipType;
      ivl = s.system.ivl;
      management = s.system.management;
      poe = s.system.poe;
      port_discovery = s.system.portDiscovery;
      stp_cost_mode = s.system.stpCostMode;
      stp_priority = s.system.stpPriority;
      watchdog = s.system.watchdog;
    };
    password = s.password;
    snmp = {
      community = s.snmp.community;
      contact = s.snmp.contact;
      enabled = s.snmp.enabled;
      location = s.snmp.location;
    };
    rstp = { enabled_ports = s.rstp.enabledPorts; };
    mirror = { target_port = s.mirror.targetPort; };
    filter_vid = s.filterVid;
    acl = s.acl;
    hosts = s.hosts;
  };

  jsonFile = pkgs.writeText "swos-${s.identity}.json" (builtins.toJSON json);
in {
  swosJson = json;
  system.build = {
    json = jsonFile;
    script = pkgs.runCommand "swos-${s.identity}.swb" { } ''
      ${swosLib.render}/bin/swos-config generate < ${jsonFile} > $out
    '';
  };
}
