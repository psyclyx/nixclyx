# RouterOS platform — render `config.routeros` to a `.rsc` script.
#
# The typed options are assembled into the JSON document the renderer
# consumes, then rendered. `system.build.json` is the desired state as
# data; `system.build.script` is the `.rsc` the device imports.
{ config, lib, pkgs, routerosLib, ... }:
let
  r = config.routeros;

  # Drop null-valued keys, so the renderer sees "unset" not "null".
  keep = lib.filterAttrs (_: v: v != null);

  json = {
    inherit (r) model;
    system = {
      identity = r.identity;
      timezone = r.timezone;
      dns_servers = r.system.dnsServers;
      l3_hw_offload = r.system.l3HwOffload;
      ssh = {
        host_key_type = "ed25519";
        keys = map (k: { inherit (k) key user; }) r.system.sshKeys;
      };
      snmp = { enabled = r.system.snmp.enable; };
    };
    ethernet_switches = map (c: { name = c.name; l3_hw_offload = c.l3HwOffload; }) r.ethernetSwitches;
    l3hw_settings = keep {
      ipv6_hw = r.l3hwSettings.ipv6Hw;
      icmp_reply_on_error = r.l3hwSettings.icmpReplyOnError;
    };
    interfaces = map (i: { inherit (i) name enabled; } // keep { l2mtu = i.l2mtu; }) r.interfaces;
    bonds = map (b: {
      name = b.name; mode = b.mode; slaves = b.slaves;
      lacp_mode = b.lacpMode; comment = b.comment;
    }) r.bonds;
    bridge = {
      name = r.bridge.name;
      protocol_mode = r.bridge.protocolMode;
      vlan_filtering = r.bridge.vlanFiltering;
      igmp_snooping = r.bridge.igmpSnooping;
      multicast_querier = r.bridge.multicastQuerier;
      multicast_router = r.bridge.multicastRouter;
      igmp_version = r.bridge.igmpVersion;
      mld_version = r.bridge.mldVersion;
      ports = map (p: { inherit (p) interface pvid comment; }) r.bridge.ports;
      vlans = map (v: { vlan_ids = v.vlanIds; inherit (v) tagged untagged; }) r.bridge.vlans;
    };
    vlan_interfaces = map (v: {
      interface = v.interface; name = v.name; vlan_id = v.vlanId; mtu = v.mtu;
    }) r.vlanInterfaces;
    addresses = map (a: { inherit (a) address interface; } // keep { network = a.network; }) r.addresses;
    ipv6_addresses = map (a: keep {
      interface = a.interface; address = a.address;
      from_pool = a.fromPool; advertise = a.advertise;
    }) r.ipv6Addresses;
    dhcp_relays = map (d: {
      name = d.name; interface = d.interface;
      dhcp_server = d.dhcpServer; local_address = d.localAddress; disabled = d.disabled;
    }) r.dhcpRelays;
    ipv6_settings = keep { forwarding = r.ipv6Settings.forwarding; };
    ipv6_nd = map (n: { interface = n.interface; } // keep { ra_lifetime = n.raLifetime; }) r.ipv6Nd;
    ipv6_dhcp_clients = map (c: {
      interface = c.interface; request = c.request;
      pool_name = c.poolName; pool_prefix_length = c.poolPrefixLength;
      add_default_route = c.addDefaultRoute;
    }) r.ipv6DhcpClients;
    switch_rules = map (s: keep {
      switch = s.switch; vlan_id = s.vlanId;
      src_address = s.srcAddress; dst_address = s.dstAddress;
      src_address6 = s.srcAddress6; dst_address6 = s.dstAddress6;
      protocol = s.protocol; dst_port = s.dstPort;
      new_dst_ports = s.newDstPorts; comment = s.comment;
    }) r.switchRules;
    routes = map (x: { inherit (x) dst gateway disabled comment; }) r.routes;
    ipv6_routes = map (x: { inherit (x) dst gateway disabled comment; }) r.ipv6Routes;
  };

  jsonFile = pkgs.writeText "routeros-${r.identity}.json" (builtins.toJSON json);
in {
  routerosJson = json;
  system.build = {
    json = jsonFile;
    script = pkgs.runCommand "routeros-${r.identity}.rsc" { } ''
      ${routerosLib.render}/bin/routeros-config generate < ${jsonFile} > $out
    '';
  };
}
