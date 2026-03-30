#!/usr/bin/env python3
"""routeros-config: Generate RouterOS switch/router configuration scripts.

Produces complete .rsc scripts for MikroTik CRS3xx series switches
from a declarative JSON configuration.  Supports both pure L2 switching
and L3 hardware-offloaded routing (inter-VLAN routing, firewall, DHCP,
static routes).

Usage:
    routeros-config generate < config.json > config.rsc
"""

import argparse
import json
import sys


# ── Helpers ──────────────────────────────────────────────────────────

# Hardware port lists for known models.  Unknown models use the ports
# from the JSON config.
MODEL_PORTS = {
    "CRS326-24S+2Q+RM": (
        [f"sfp-sfpplus{i}" for i in range(1, 25)]
        + [
            f"qsfpplus{q}-{s}"
            for q in range(1, 3)
            for s in range(1, 5)
        ]
    ),
    "CRS305-1G-4S+IN": (
        ["ether1"] + [f"sfp-sfpplus{i}" for i in range(1, 5)]
    ),
    "CSS326-24G-2S+RM": (
        [f"ether{i}" for i in range(1, 25)]
        + ["sfp-sfpplus1", "sfp-sfpplus2"]
    ),
}


def _port_sort_key(name):
    """Natural sort key: split trailing digits for numeric comparison."""
    import re

    m = re.match(r"^(.*?)(\d+)$", name)
    if m:
        return (m.group(1), int(m.group(2)))
    return (name, 0)


def _sorted_ports(names):
    return sorted(names, key=_port_sort_key)


def _comma_list(items):
    return ",".join(items)


# Firewall rule fields in canonical RouterOS order.
_FW_FIELDS = [
    ("chain", "chain", str),
    ("action", "action", str),
    ("connection_state", "connection-state", str),
    ("connection_nat_state", "connection-nat-state", str),
    ("protocol", "protocol", str),
    ("src_address", "src-address", str),
    ("dst_address", "dst-address", str),
    ("src_address_list", "src-address-list", str),
    ("dst_address_list", "dst-address-list", str),
    ("src_port", "src-port", str),
    ("dst_port", "dst-port", str),
    ("in_interface", "in-interface", str),
    ("out_interface", "out-interface", str),
    ("in_interface_list", "in-interface-list", str),
    ("out_interface_list", "out-interface-list", str),
    ("in_bridge_port", "in-bridge-port", str),
    ("out_bridge_port", "out-bridge-port", str),
    ("layer7_protocol", "layer7-protocol", str),
    ("packet_mark", "packet-mark", str),
    ("connection_mark", "connection-mark", str),
    ("routing_mark", "routing-mark", str),
    ("new_packet_mark", "new-packet-mark", str),
    ("new_connection_mark", "new-connection-mark", str),
    ("new_routing_mark", "new-routing-mark", str),
    ("passthrough", "passthrough", bool),
    ("log", "log", bool),
    ("log_prefix", "log-prefix", str),
    ("to_addresses", "to-addresses", str),
    ("to_ports", "to-ports", str),
    ("jump_target", "jump-target", str),
    ("disabled", "disabled", bool),
    ("comment", "comment", str),
]


def _firewall_rule(rule):
    """Serialize a single firewall rule dict to a RouterOS add command."""
    parts = ["add"]
    for json_key, ros_key, typ in _FW_FIELDS:
        val = rule.get(json_key)
        if val is None:
            continue
        if typ is bool:
            parts.append(f"{ros_key}={'yes' if val else 'no'}")
        elif json_key == "comment":
            parts.append(f'{ros_key}="{val}"')
        else:
            parts.append(f"{ros_key}={val}")
    return " ".join(parts)


# ── Generator ────────────────────────────────────────────────────────


def generate(config):
    """Generate a complete .rsc script from a JSON config."""
    lines = []

    system = config.get("system", {})
    ifaces = {i["name"]: i for i in config.get("interfaces", [])}
    bonds = config.get("bonds", [])
    bridge = config.get("bridge", {})
    bridge_ports = bridge.get("ports", [])
    bridge_vlans = bridge.get("vlans", [])
    vlan_ifaces = config.get("vlan_interfaces", [])
    addresses = config.get("addresses", [])
    routes = config.get("routes", [])

    # Determine model and all hardware ports
    model = config.get("model", "")
    hw_ports = MODEL_PORTS.get(model, [])
    declared_ports = set(ifaces.keys())
    if hw_ports:
        all_port_names = _sorted_ports(hw_ports)
    else:
        all_port_names = _sorted_ports(declared_ports)

    # Bond slave lookup
    bond_slaves = {}
    for b in bonds:
        for s in b["slaves"]:
            bond_slaves[s] = b["name"]

    # Identify disabled ports — in hw list but not in declared interfaces,
    # or explicitly disabled.
    disabled_ports = []
    for name in all_port_names:
        if name in ifaces:
            if not ifaces[name].get("enabled", True):
                disabled_ports.append(name)
        elif hw_ports:
            disabled_ports.append(name)

    # Active interfaces on the bridge
    bridge_iface_names = [bp["interface"] for bp in bridge_ports]

    # ── Header ──────────────────────────────────────────────────
    identity = system.get("identity", "router")
    lines.append(f"# RouterOS configuration for {model} ({identity})")
    lines.append(
        "# Generated from switch configuration data — do not edit manually."
    )

    # Port map comment
    if bridge_ports:
        lines.append("#")
        lines.append("# Port map:")
        for bp in bridge_ports:
            comment = bp.get("comment", bp["interface"])
            pvid = bp.get("pvid", 1)
            pvid_note = f" (VLAN {pvid})" if pvid != 1 else ""
            lines.append(f"#   {bp['interface']}: {comment}{pvid_note}")
        lines.append("#")

    lines.append("")

    # ── System ──────────────────────────────────────────────────
    lines.append("# ── System ──")
    lines.append(f'/system identity set name="{identity}"')

    tz = system.get("timezone")
    if tz:
        lines.append(f"/system clock set time-zone-name={tz}")

    dns = system.get("dns_servers", [])
    if dns:
        lines.append(f"/ip dns set servers={_comma_list(dns)}")

    ntp = system.get("ntp_servers", [])
    if ntp:
        lines.append("/system ntp client set enabled=yes")
        lines.append(f"/system ntp client servers add address={ntp[0]}")

    ssh = system.get("ssh", {})
    hkt = ssh.get("host_key_type")
    if hkt:
        lines.append(f"/ip ssh set host-key-type={hkt}")

    snmp = system.get("snmp", {})
    if snmp.get("enabled"):
        parts = ["/snmp set enabled=yes"]
        if snmp.get("community"):
            parts.append(f'community={snmp["community"]}')
        if snmp.get("contact"):
            parts.append(f'contact="{snmp["contact"]}"')
        if snmp.get("location"):
            parts.append(f'location="{snmp["location"]}"')
        lines.append(" ".join(parts))

    # SSH keys
    ssh_keys = ssh.get("keys", [])
    if ssh_keys:
        lines.append("# ── SSH keys ──")
        for idx, k in enumerate(ssh_keys, 1):
            user = k.get("user", "admin")
            key = k["key"]
            fname = f"admin-key{idx}.pub"
            lines.append(f'/file add name={fname} contents="{key}"')
            lines.append(
                f"/user ssh-keys import public-key-file={fname} user={user}"
            )
            lines.append(f":do {{ /file remove {fname} }} on-error={{}}")

    lines.append("")

    # ── Interface settings ──────────────────────────────────────
    iface_settings = []
    for name in all_port_names:
        if name not in ifaces or name in disabled_ports:
            continue
        iface = ifaces[name]
        parts = []
        if iface.get("comment"):
            parts.append(f'comment="{iface["comment"]}"')
        if iface.get("mtu") is not None:
            parts.append(f'mtu={iface["mtu"]}')
        if iface.get("l2mtu") is not None:
            parts.append(f'l2mtu={iface["l2mtu"]}')
        if parts:
            iface_settings.append(
                f"set [find default-name={name}] {' '.join(parts)}"
            )
    if iface_settings:
        lines.append("# ── Interface settings ──")
        lines.append("/interface ethernet")
        lines.extend(iface_settings)
        lines.append("")

    # ── Bonds ───────────────────────────────────────────────────
    if bonds:
        lines.append("# ── Bonds ──")
        lines.append("/interface bonding")
        for b in bonds:
            parts = [
                f"add name={b['name']}",
                f"mode={b['mode']}",
                f"slaves={_comma_list(b['slaves'])}",
            ]
            if b.get("lacp_mode"):
                parts.append(f"lacp-mode={b['lacp_mode']}")
            if b.get("comment"):
                parts.append(f'comment="{b["comment"]}"')
            lines.append(" ".join(parts))
        lines.append("")

    # ── Bridge ──────────────────────────────────────────────────
    if bridge.get("name"):
        lines.append("# ── Bridge ──")
        lines.append("/interface bridge")
        parts = [f"add name={bridge['name']}"]
        pm = bridge.get("protocol_mode")
        if pm:
            parts.append(f"protocol-mode={pm}")
        if bridge.get("igmp_snooping") is not None:
            parts.append(
                f"igmp-snooping={'yes' if bridge['igmp_snooping'] else 'no'}"
            )
        if bridge.get("priority") is not None:
            parts.append(f"priority={bridge['priority']:#06x}")
        if bridge.get("ageing_time") is not None:
            parts.append(f"ageing-time={bridge['ageing_time']}")
        if bridge.get("forward_delay") is not None:
            parts.append(f"forward-delay={bridge['forward_delay']}")
        if bridge.get("max_age") is not None:
            parts.append(f"max-age={bridge['max_age']}")
        lines.append(" ".join(parts))
        lines.append("")

        # ── Bridge ports ────────────────────────────────────────
        if bridge_ports:
            lines.append("# ── Bridge ports ──")
            lines.append("/interface bridge port")
            for bp in bridge_ports:
                parts = [
                    f"add bridge={bridge['name']}",
                    f"interface={bp['interface']}",
                ]
                if bp.get("pvid") is not None:
                    parts.append(f"pvid={bp['pvid']}")
                if bp.get("frame_types"):
                    parts.append(f"frame-types={bp['frame_types']}")
                if bp.get("ingress_filtering") is not None:
                    val = "yes" if bp["ingress_filtering"] else "no"
                    parts.append(f"ingress-filtering={val}")
                if bp.get("edge") is not None:
                    parts.append(f"edge={'yes' if bp['edge'] else 'no'}")
                if bp.get("point_to_point") is not None:
                    val = "yes" if bp["point_to_point"] else "no"
                    parts.append(f"point-to-point={val}")
                if bp.get("path_cost") is not None:
                    parts.append(f"path-cost={bp['path_cost']}")
                if bp.get("priority") is not None:
                    parts.append(f"priority={bp['priority']:#04x}")
                if bp.get("comment"):
                    parts.append(f'comment="{bp["comment"]}"')
                lines.append(" ".join(parts))
            lines.append("")

        # ── VLAN table ──────────────────────────────────────────
        if bridge_vlans:
            lines.append("# ── VLAN table ──")
            lines.append("/interface bridge vlan")
            for bv in bridge_vlans:
                parts = [
                    f"add bridge={bridge['name']}",
                    f"vlan-ids={bv['vlan_ids']}",
                ]
                tagged = bv.get("tagged", [])
                untagged = bv.get("untagged", [])
                if tagged:
                    parts.append(f"tagged={_comma_list(tagged)}")
                if untagged:
                    parts.append(f"untagged={_comma_list(untagged)}")
                lines.append(" ".join(parts))
            lines.append("")

    # ── VLAN interfaces ─────────────────────────────────────────
    if vlan_ifaces:
        lines.append("# ── VLAN interfaces ──")
        lines.append("/interface vlan")
        for vi in vlan_ifaces:
            parts = [
                f"add interface={vi['interface']}",
                f"name={vi['name']}",
                f"vlan-id={vi['vlan_id']}",
            ]
            if vi.get("comment"):
                parts.append(f'comment="{vi["comment"]}"')
            lines.append(" ".join(parts))
        lines.append("")

    # ── IP settings (L3 forwarding) ────────────────────────────
    ip_settings = config.get("ip_settings", {})
    if ip_settings:
        lines.append("# ── IP settings ──")
        parts = ["/ip settings set"]
        if ip_settings.get("forwarding") is not None:
            val = "yes" if ip_settings["forwarding"] else "no"
            parts.append(f"ip-forward={val}")
        if ip_settings.get("allow_fast_path") is not None:
            val = "yes" if ip_settings["allow_fast_path"] else "no"
            parts.append(f"allow-fast-path={val}")
        if ip_settings.get("accept_redirects") is not None:
            val = "yes" if ip_settings["accept_redirects"] else "no"
            parts.append(f"accept-redirects={val}")
        if ip_settings.get("accept_source_route") is not None:
            val = "yes" if ip_settings["accept_source_route"] else "no"
            parts.append(f"accept-source-route={val}")
        if ip_settings.get("secure_redirects") is not None:
            val = "yes" if ip_settings["secure_redirects"] else "no"
            parts.append(f"secure-redirects={val}")
        if ip_settings.get("rp_filter") is not None:
            parts.append(f"rp-filter={ip_settings['rp_filter']}")
        if len(parts) > 1:
            lines.append(" ".join(parts))
        lines.append("")

    # ── IP addresses ────────────────────────────────────────────
    if addresses:
        lines.append("# ── IP addresses ──")
        lines.append("/ip address")
        for a in addresses:
            parts = [f"add address={a['address']}"]
            parts.append(f"interface={a['interface']}")
            if a.get("network"):
                parts.append(f"network={a['network']}")
            if a.get("comment"):
                parts.append(f'comment="{a["comment"]}"')
            lines.append(" ".join(parts))
        lines.append("")

    # ── Routes ──────────────────────────────────────────────────
    if routes:
        lines.append("# ── Routes ──")
        lines.append("/ip route")
        for r in routes:
            parts = []
            if r.get("disabled"):
                parts.append("add disabled=yes")
            else:
                parts.append("add")
            parts.append(f"dst-address={r['dst']}")
            parts.append(f"gateway={r['gateway']}")
            if r.get("distance") is not None:
                parts.append(f"distance={r['distance']}")
            if r.get("routing_table"):
                parts.append(f"routing-table={r['routing_table']}")
            if r.get("scope") is not None:
                parts.append(f"scope={r['scope']}")
            if r.get("target_scope") is not None:
                parts.append(f"target-scope={r['target_scope']}")
            if r.get("pref_src"):
                parts.append(f"pref-src={r['pref_src']}")
            if r.get("comment"):
                parts.append(f'comment="{r["comment"]}"')
            lines.append(" ".join(parts))
        lines.append("")

    # ── Firewall ────────────────────────────────────────────────
    firewall = config.get("firewall", {})

    fw_filter = firewall.get("filter", [])
    if fw_filter:
        lines.append("# ── Firewall filter ──")
        lines.append("/ip firewall filter")
        for rule in fw_filter:
            lines.append(_firewall_rule(rule))
        lines.append("")

    fw_nat = firewall.get("nat", [])
    if fw_nat:
        lines.append("# ── Firewall NAT ──")
        lines.append("/ip firewall nat")
        for rule in fw_nat:
            lines.append(_firewall_rule(rule))
        lines.append("")

    fw_mangle = firewall.get("mangle", [])
    if fw_mangle:
        lines.append("# ── Firewall mangle ──")
        lines.append("/ip firewall mangle")
        for rule in fw_mangle:
            lines.append(_firewall_rule(rule))
        lines.append("")

    fw_raw = firewall.get("raw", [])
    if fw_raw:
        lines.append("# ── Firewall raw ──")
        lines.append("/ip firewall raw")
        for rule in fw_raw:
            lines.append(_firewall_rule(rule))
        lines.append("")

    # ── DHCP ────────────────────────────────────────────────────
    dhcp = config.get("dhcp", {})

    dhcp_pools = dhcp.get("pools", [])
    if dhcp_pools:
        lines.append("# ── DHCP pools ──")
        lines.append("/ip pool")
        for pool in dhcp_pools:
            for r in pool["ranges"]:
                lines.append(f"add name={pool['name']} ranges={r}")
        lines.append("")

    dhcp_networks = dhcp.get("networks", [])
    if dhcp_networks:
        lines.append("# ── DHCP networks ──")
        lines.append("/ip dhcp-server network")
        for net in dhcp_networks:
            parts = [f"add address={net['address']}"]
            if net.get("gateway"):
                parts.append(f"gateway={net['gateway']}")
            if net.get("dns_server"):
                dns_val = net["dns_server"]
                if isinstance(dns_val, list):
                    dns_val = _comma_list(dns_val)
                parts.append(f"dns-server={dns_val}")
            if net.get("domain"):
                parts.append(f"domain={net['domain']}")
            if net.get("ntp_server"):
                parts.append(f"ntp-server={net['ntp_server']}")
            if net.get("comment"):
                parts.append(f'comment="{net["comment"]}"')
            lines.append(" ".join(parts))
        lines.append("")

    dhcp_servers = dhcp.get("servers", [])
    if dhcp_servers:
        lines.append("# ── DHCP servers ──")
        lines.append("/ip dhcp-server")
        for srv in dhcp_servers:
            parts = [f"add name={srv['name']}"]
            parts.append(f"interface={srv['interface']}")
            parts.append(f"address-pool={srv['address_pool']}")
            if srv.get("lease_time"):
                parts.append(f"lease-time={srv['lease_time']}")
            if srv.get("disabled"):
                parts.append("disabled=yes")
            if srv.get("authoritative"):
                parts.append(f"authoritative={srv['authoritative']}")
            if srv.get("comment"):
                parts.append(f'comment="{srv["comment"]}"')
            lines.append(" ".join(parts))
        lines.append("")

    dhcp_relay = dhcp.get("relay", {})
    if dhcp_relay.get("enabled"):
        lines.append("# ── DHCP relay ──")
        lines.append("/ip dhcp-relay")
        parts = [
            f"add name={dhcp_relay.get('name', 'dhcp-relay')}",
            f"interface={dhcp_relay['interface']}",
            f"dhcp-server={dhcp_relay['dhcp_server']}",
        ]
        if dhcp_relay.get("local_address"):
            parts.append(f"local-address={dhcp_relay['local_address']}")
        lines.append(" ".join(parts))
        lines.append("")

    dhcp_leases = dhcp.get("leases", [])
    if dhcp_leases:
        lines.append("# ── DHCP static leases ──")
        lines.append("/ip dhcp-server lease")
        for lease in dhcp_leases:
            parts = [f"add address={lease['address']}"]
            parts.append(f"mac-address={lease['mac_address']}")
            if lease.get("server"):
                parts.append(f"server={lease['server']}")
            if lease.get("comment"):
                parts.append(f'comment="{lease["comment"]}"')
            lines.append(" ".join(parts))
        lines.append("")

    # ── Disable unused ports ────────────────────────────────────
    if disabled_ports:
        lines.append("# ── Disable unused ports ──")
        lines.append("/interface ethernet")
        for name in _sorted_ports(disabled_ports):
            lines.append(f"set [find default-name={name}] disabled=yes")
        lines.append("")

    # ── Enable VLAN filtering (must be LAST) ────────────────────
    if bridge.get("name") and bridge.get("vlan_filtering"):
        lines.append(
            "# ── Enable VLAN filtering (must be LAST to avoid lockout) ──"
        )
        lines.append(
            f"/interface bridge set {bridge['name']} vlan-filtering=yes"
        )
        lines.append("")

    return "\n".join(lines)


# ── CLI ──────────────────────────────────────────────────────────────


def main():
    ap = argparse.ArgumentParser(
        description="Generate RouterOS switch configuration scripts."
    )
    sub = ap.add_subparsers(dest="command")
    sub.required = True
    sub.add_parser("generate", help="JSON stdin -> .rsc stdout")

    args = ap.parse_args()

    if args.command == "generate":
        config = json.load(sys.stdin)
        sys.stdout.write(generate(config))


if __name__ == "__main__":
    main()
