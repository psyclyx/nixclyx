#!/usr/bin/env python3
"""routeros-config: Generate RouterOS switch/router configuration scripts.

Produces complete .rsc scripts for MikroTik CRS3xx series switches
from a declarative JSON configuration.  Supports both pure L2 switching
and L3 hardware-offloaded inter-VLAN routing with static routes.

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


# ── Field schema ─────────────────────────────────────────────────────
#
# One declarative table per menu: how a spec key is named on the device
# and how its value is spelled in an .rsc script. Adding a property is
# one entry here, and `learn-schema` checks the name against what the
# device says it accepts.
#
#   omit:  "req"    always emit (mandatory)
#          "none"   skip when the python value is None (0 / "" still emit)
#          "falsy"  skip when the python value is falsy
#   kind:  "raw"    value verbatim
#          "int"    str(value)
#          "bool"   True→yes  False→no
#          "flag"   emit `key=yes` when truthy, else skip entirely
#          "qstr"   always double-quoted (comments)
#          "list"   comma-joined


class Field:
    __slots__ = ("py", "ros", "kind", "omit")

    def __init__(self, py, ros=None, kind="raw", omit="none"):
        self.py = py
        self.ros = ros if ros is not None else py.replace("_", "-")
        self.kind = kind
        self.omit = omit

    def _skip(self, v):
        if self.kind == "flag":
            return not v
        if self.omit == "req":
            return False
        if self.omit == "falsy":
            return not v
        return v is None

    def render(self, entry):
        """py-keyed entry → `ros-key=value` rsc token, or None to skip."""
        v = entry.get(self.py)
        if self._skip(v):
            return None
        if self.kind == "flag":
            return f"{self.ros}=yes"
        if self.kind == "bool":
            return f"{self.ros}={'yes' if v else 'no'}"
        if self.kind == "qstr":
            return f'{self.ros}="{v}"'
        if self.kind == "list":
            return f"{self.ros}={_comma_list(v)}"
        return f"{self.ros}={v}"


F = Field


class Section:
    """A RouterOS menu and the properties we write to it.

    Two jobs: it gives the generator its field list, and it tells
    `learn-schema` which menus to ask the device about — so every
    property named here is checked against the device's own schema
    before a script that mentions it is ever emitted.
    """

    __slots__ = ("path", "fields")

    def __init__(self, path, fields):
        self.path = path
        self.fields = fields


# Order is the generator's emit order, and for record sections the field
# order must match RouterOS's own so a generated script reads like an
# export.
_ROUTE_FIELDS = [
    # Explicit yes/no rather than a bare `disabled=yes` flag, so a route
    # that is meant to be disabled says so instead of going silent.
    F("disabled", kind="bool"),
    F("dst", "dst-address", omit="req"), F("gateway", omit="req"),
    F("distance", kind="int"), F("routing_table", "routing-table", omit="falsy"),
    F("scope", kind="int"), F("target_scope", "target-scope", kind="int"),
    F("pref_src", "pref-src", omit="falsy"),
    F("comment", kind="qstr", omit="falsy"),
]

SECTIONS = [
    Section("/interface vlan",
            [
                F("interface", omit="req"), F("name", omit="req"),
                F("vlan_id", "vlan-id", kind="int", omit="req"),
                F("mtu", kind="int"),
                F("comment", kind="qstr", omit="falsy")]),
    # Bridge VLAN table — structurally nested under the bridge in the
    # spec, its own menu on the device.
    Section("/interface bridge vlan",
            [
                F("bridge", omit="req"),
                F("vlan_ids", "vlan-ids", omit="req"),
                F("tagged", kind="list", omit="falsy"),
                F("untagged", kind="list", omit="falsy")]),
    Section("/ip address",
            [
                F("address", omit="req"), F("interface", omit="req"),
                F("network", omit="falsy"),
                F("comment", kind="qstr", omit="falsy")]),
    Section("/ip route",
            _ROUTE_FIELDS),
    Section("/ip dhcp-relay",
            [
                F("name", omit="req"), F("interface", omit="req"),
                F("dhcp_server", "dhcp-server", kind="list", omit="req"),
                F("local_address", "local-address", omit="falsy"),
                F("disabled", kind="bool")]),
    Section("/ipv6 address",
            [
                # Either a literal address or a draw from a delegated
                # pool — never both. The pool case is how a segment gets
                # a global prefix without anyone writing one down.
                F("address", omit="falsy"), F("interface", omit="req"),
                F("from_pool", "from-pool", omit="falsy"),
                F("advertise", kind="bool"),
                F("eui64", "eui-64", kind="bool"),
                F("no_dad", "no-dad", kind="bool"),
                F("comment", kind="qstr", omit="falsy")]),
    # DHCPv6-PD client. What the switch runs to receive a slice of the
    # upstream delegation: the prefix lands in a named pool and SVI
    # addresses draw /64s from it. RouterOS re-derives both when the
    # prefix changes, which is what makes a renumber a non-event here.
    Section("/ipv6 dhcp-client",
            [
                F("interface", omit="req"),
                F("request", omit="req"),
                F("pool_name", "pool-name", omit="falsy"),
                F("pool_prefix_length", "pool-prefix-length", kind="int"),
                F("add_default_route", "add-default-route", kind="bool"),
                F("comment", kind="qstr", omit="falsy")]),
    Section("/ipv6 nd",
            [
                F("interface", omit="req"),
                F("ra_lifetime", "ra-lifetime"),
                F("comment", kind="qstr", omit="falsy")]),
    Section("/ipv6 route",
            _ROUTE_FIELDS),
    # Switch chips. Rows the hardware defines — a CRS326 has a Marvell
    # primary plus an Atheros secondary — so we reconfigure them and
    # never add or remove. Which chip gets which setting is the spec's
    # business, not ours; nothing here knows the name "switch1".
    Section("/interface ethernet switch",
            [
                F("name", omit="req"),
                F("l3_hw_offload", "l3-hw-offloading", kind="bool"),
                F("qos_hw_offload", "qos-hw-offloading", kind="bool")]),
    # Switch-chip ACLs. The only place policy can be applied to
    # hardware-forwarded traffic: once the chip routes a packet it never
    # reaches /ip firewall, so a rule there is not merely unenforced, it
    # is unenforceable. Rules are first-match-wins, and an empty
    # new-dst-ports is how RouterOS spells "drop".
    #
    # Matching on vlan-id rather than on addresses is what makes this
    # survive an ISP renumber: the segment a packet entered on is a fact
    # about the fabric, not about whatever prefix the delegation
    # currently carries.
    Section("/interface ethernet switch rule", [
                F("switch", omit="req"),
                F("vlan_id", "vlan-id", kind="int", omit="none"),
                F("src_address", "src-address", omit="none"),
                F("dst_address", "dst-address", omit="none"),
                F("src_address6", "src-address6", omit="none"),
                F("dst_address6", "dst-address6", omit="none"),
                F("protocol", omit="none"),
                F("dst_port", "dst-port", omit="none"),
                F("new_dst_ports", "new-dst-ports", kind="qstr", omit="none"),
                F("comment", kind="qstr", omit="falsy")]),
    Section("/interface ethernet switch l3hw-settings",
            [
                F("ipv6_hw", "ipv6-hw", kind="bool"),
                F("icmp_reply_on_error", "icmp-reply-on-error", kind="bool")]),
    Section("/ipv6 settings",
            [
                F("forwarding", "forward", kind="bool"),
                # Enums here ("yes-if-forwarding-disabled"), not booleans.
                F("accept_redirects", "accept-redirects")]),
    # Device-level settings menus — one implicit row each.
    Section("/system identity",
            [F("identity", "name", kind="qstr", omit="falsy")]),
    Section("/system clock",
            [F("timezone", "time-zone-name", omit="falsy")]),
    Section("/ip dns",
            [F("dns_servers", "servers", kind="list", omit="falsy")]),
    Section("/ip ssh",
            [F("host_key_type", "host-key-type", omit="falsy")]),
    Section("/snmp",
            [
                F("enabled", kind="bool"),
                F("contact", kind="qstr", omit="falsy"),
                F("location", kind="qstr", omit="falsy")]),
]

_SECTION_BY_PATH = {s.path: s for s in SECTIONS}


def _emit_add(fields, entry):
    """Render one `add …` line from a py-keyed entry and its schema."""
    parts = ["add"]
    for f in fields:
        tok = f.render(entry)
        if tok is not None:
            parts.append(tok)
    return " ".join(parts)


def _emit_record_section(lines, header, comment, fields, entries):
    if not entries:
        return
    lines.append(comment)
    lines.append(header)
    for e in entries:
        lines.append(_emit_add(fields, e))
    lines.append("")


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
    addresses6 = config.get("ipv6_addresses", [])
    nd6 = config.get("ipv6_nd", [])
    routes = config.get("routes", [])
    routes6 = config.get("ipv6_routes", [])
    dhcp_relays = config.get("dhcp_relays", [])

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
    #
    # User accounts and SSH service come FIRST so that even if a later
    # section errors out mid-script, we retain SSH access to recover.
    # After `system reset-configuration no-defaults=yes`, the switch has
    # no users and ssh is disabled — we have to (re)create both before
    # anything else.
    lines.append("# ── System ──")
    lines.append(f'/system identity set name="{identity}"')

    ssh = system.get("ssh", {})
    ssh_keys = ssh.get("keys", [])

    # Unique users mentioned in the SSH keys list (typically just "admin").
    users_needed = sorted({k.get("user", "admin") for k in ssh_keys})
    if users_needed:
        lines.append("# ── User accounts (lockout-safety: do this before everything else) ──")
        for user in users_needed:
            # Idempotent: try add, fall back to set if user already exists.
            # password="" + key-only login is the canonical RouterOS
            # pattern. Group `full` so the SSH-key user can run anything.
            lines.append(
                f':do {{ /user add name={user} group=full password="" }} '
                f'on-error={{ /user set [find name={user}] group=full password="" }}'
            )
        lines.append("/ip service set [find name=ssh] disabled=no port=22")
        lines.append("")

    # SSH keys (now that the user exists).
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

    hkt = ssh.get("host_key_type")
    if hkt:
        lines.append(f"/ip ssh set host-key-type={hkt}")

    snmp = system.get("snmp", {})
    if snmp.get("enabled"):
        parts = ["/snmp set enabled=yes"]
        if snmp.get("contact"):
            parts.append(f'contact="{snmp["contact"]}"')
        if snmp.get("location"):
            parts.append(f'location="{snmp["location"]}"')
        lines.append(" ".join(parts))

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
        if bridge.get("multicast_querier") is not None:
            parts.append(
                f"multicast-querier={'yes' if bridge['multicast_querier'] else 'no'}"
            )
        if bridge.get("multicast_router") is not None:
            parts.append(f"multicast-router={bridge['multicast_router']}")
        if bridge.get("igmp_version") is not None:
            parts.append(f"igmp-version={bridge['igmp_version']}")
        if bridge.get("mld_version") is not None:
            parts.append(f"mld-version={bridge['mld_version']}")
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
    _emit_record_section(
        lines, "/interface vlan", "# ── VLAN interfaces ──",
        _SECTION_BY_PATH["/interface vlan"].fields, vlan_ifaces)

    # ── L3 hardware offloading ─────────────────────────────────
    # Two distinct knobs land here:
    #   ethernet_switches[] — per-chip settings, chiefly l3-hw-offloading,
    #     which enables inter-VLAN routing offload on Marvell Prestera
    #     chipsets (CRS3xx, RouterOS 7.6+). The spec names the chip; we
    #     don't guess it.
    #   l3hw_settings.* (dict) — fine-grained switch-chip L3 knobs
    #     (IPv6 hardware path, ICMP reply behavior). Maps to
    #     `/interface ethernet switch l3hw-settings set ...`.
    #
    # NOT `/interface bridge settings` — that menu has no
    # `l3-hw-offloading` property (only use-ip-firewall*, allow-fast-path).
    # `/import` halts on the first error and `deploy` runs the script via
    # `reset-configuration no-defaults=yes`, so emitting it there aborted
    # the script partway and left the switch with no addresses at all.
    for chip in config.get("ethernet_switches", []):
        sec = _SECTION_BY_PATH["/interface ethernet switch"]
        settings = [
            f.render(chip) for f in sec.fields if f.py != "name"
        ]
        settings = [s for s in settings if s is not None]
        if not settings:
            continue
        lines.append("# ── Switch chip L3 hardware offloading ──")
        lines.append(
            f"/interface ethernet switch set [find name={chip['name']}] "
            + " ".join(settings)
        )
        lines.append("")

    l3hw = config.get("l3hw_settings", {})
    if l3hw:
        lines.append("# ── L3HW chip settings ──")
        parts = ["/interface ethernet switch l3hw-settings set"]
        if l3hw.get("ipv6_hw") is not None:
            val = "yes" if l3hw["ipv6_hw"] else "no"
            parts.append(f"ipv6-hw={val}")
        if l3hw.get("icmp_reply_on_error") is not None:
            val = "yes" if l3hw["icmp_reply_on_error"] else "no"
            parts.append(f"icmp-reply-on-error={val}")
        if len(parts) > 1:
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

    # ── IPv6 settings ──────────────────────────────────────────
    ipv6_settings = config.get("ipv6_settings", {})
    if ipv6_settings:
        lines.append("# ── IPv6 settings ──")
        parts = ["/ipv6 settings set"]
        if ipv6_settings.get("forwarding") is not None:
            val = "yes" if ipv6_settings["forwarding"] else "no"
            parts.append(f"forward={val}")
        if ipv6_settings.get("accept_redirects") is not None:
            val = "yes" if ipv6_settings["accept_redirects"] else "no"
            parts.append(f"accept-redirects={val}")
        if ipv6_settings.get("accept_router_advertisements") is not None:
            val = ipv6_settings["accept_router_advertisements"]
            parts.append(f"accept-router-advertisements={val}")
        if len(parts) > 1:
            lines.append(" ".join(parts))
        lines.append("")

    # ── IP addresses ────────────────────────────────────────────
    _emit_record_section(
        lines, "/ip address", "# ── IP addresses ──",
        _SECTION_BY_PATH["/ip address"].fields, addresses)

    # ── Routes ──────────────────────────────────────────────────
    _emit_record_section(
        lines, "/ip route", "# ── Routes ──",
        _SECTION_BY_PATH["/ip route"].fields, routes)

    # ── DHCP relay ─────────────────────────────────────────────
    # Emitted after /ip address so the local-address it references is
    # already on the box.
    _emit_record_section(
        lines, "/ip dhcp-relay", "# ── DHCP relay ──",
        _SECTION_BY_PATH["/ip dhcp-relay"].fields, dhcp_relays)

    # ── IPv6 addresses ─────────────────────────────────────────
    _emit_record_section(
        lines, "/ipv6 address", "# ── IPv6 addresses ──",
        _SECTION_BY_PATH["/ipv6 address"].fields, addresses6)

    # ── IPv6 ND (per-interface RA overrides) ───────────────────
    # RouterOS defaults to advertising every SVI with a global v6
    # address as an IPv6 default router (ra-lifetime>0). On interfaces
    # where the switch is transit-only (it has its own gateway there),
    # that makes hosts blackhole internet v6 through it. A per-interface
    # entry with ra-lifetime=none keeps SLAAC prefix advertisement but
    # stops the switch claiming to be a default router.
    _emit_record_section(
        lines, "/ipv6 nd", "# ── IPv6 ND ──",
        _SECTION_BY_PATH["/ipv6 nd"].fields, nd6)

    # ── IPv6 routes ────────────────────────────────────────────
    _emit_record_section(
        lines, "/ipv6 route", "# ── IPv6 routes ──",
        _SECTION_BY_PATH["/ipv6 route"].fields, routes6)

    _emit_record_section(
        lines, "/ipv6 dhcp-client", "# ── DHCPv6-PD client ──",
        _SECTION_BY_PATH["/ipv6 dhcp-client"].fields,
        config.get("ipv6_dhcp_clients", []))

    # ── Switch ACLs ─────────────────────────────────────────────
    # Emitted after the VLANs and addresses they reference exist, and
    # before VLAN filtering goes on. Order within the section is the
    # order given: RouterOS stops at the first match, so a permit has to
    # precede the drop it is an exception to.
    _emit_record_section(
        lines, "/interface ethernet switch rule", "# ── Switch ACLs ──",
        _SECTION_BY_PATH["/interface ethernet switch rule"].fields,
        config.get("switch_rules", []))

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


# ── The device's own schema ───────────────────────────────────────────
#
# RouterOS will describe itself. `/console/inspect request=child` on a
# menu's `set` command enumerates that menu's real properties, per model
# and per firmware version:
#
#   /console/inspect request=child path=[:toarray "ip,route,set"]
#     → blackhole, check-gateway, comment, disabled, distance,
#       dst-address, gateway, pref-src, routing-table, scope,
#       suppress-hw-offload, target-scope, vrf-interface
#
# That's the authority on what a property is called and whether it
# exists. We keep a captured copy in the repo so `generate` works
# without a device and so a firmware upgrade shows up as a reviewable
# diff — and re-read it on every apply, because a schema we believe and
# a device that disagrees is exactly how you write a config that imports
# halfway and stops.
#
# What it does NOT tell us, and we therefore still declare: which
# properties name a row (RouterOS addresses rows by `.id`, which a spec
# for a row that doesn't exist yet cannot know), and which menus are
# ours to manage at all.

SCHEMA_PATH = "@schema@"

# `set` takes these to choose which rows to act on. They're arguments of
# the command, not properties of a row.
_NON_PROPERTY_ARGS = {"numbers", "find"}


def schema_command(paths):
    """Remote command returning the property list for each given menu."""
    parts = ";".join(
        '"{p}"=[/console/inspect request=child '
        'path=[:toarray "{arg}"] as-value]'.format(
            p=p, arg=",".join(p.strip("/").split(" ") + ["set"]))
        for p in paths
    )
    return ":put [:serialize to=json {" + parts + "}]"


def parse_schema(text):
    """Inspect output → {menu path: sorted property names}."""
    raw = json.loads(text)
    out = {}
    for path, nodes in raw.items():
        if not nodes:
            continue
        out[path] = sorted(
            n["name"] for n in nodes
            if n.get("node-type") == "arg"
            and n.get("name") not in _NON_PROPERTY_ARGS
        )
    return out


def load_schema(path=None):
    """The committed schema, or {} when it hasn't been captured yet."""
    path = path or SCHEMA_PATH
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError):
        return {}


def schema_violations(schema, sections=None):
    """Properties our sections name that the device's schema doesn't have.

    A property we're wrong about is a line the device rejects, and the
    deploy script runs after a wipe — so catching it here is the
    difference between a clean refusal and a half-configured switch.
    """
    if not schema:
        return []
    out = []
    for s in sections or SECTIONS:
        known = schema.get(s.path)
        if known is None:
            continue
        for f in s.fields:
            if f.ros not in known:
                out.append(f"{s.path}: no property '{f.ros}'")
    return out


# ── CLI ──────────────────────────────────────────────────────────────


def cmd_learn_schema(args):
    """Capture the device's property schema for the menus we manage."""
    import shlex
    import subprocess

    ssh_extra = shlex.split(args.ssh_args) if args.ssh_args else []
    paths = [s.path for s in SECTIONS]
    proc = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", *ssh_extra, args.ssh,
         schema_command(paths)],
        capture_output=True, text=True, timeout=60,
    )
    if proc.returncode != 0:
        sys.stderr.write(f"ssh failed: {proc.stderr}\n")
        return proc.returncode
    try:
        schema = parse_schema(proc.stdout)
    except json.JSONDecodeError as e:
        sys.stderr.write(
            f"{args.ssh}: could not parse schema as JSON ({e}). "
            f"Device said:\n{proc.stdout[:500]}\n")
        return 1

    missing = [p for p in paths if p not in schema]
    if missing:
        sys.stderr.write(
            "warning: device reported no properties for: "
            + ", ".join(missing) + "\n")

    sys.stdout.write(json.dumps(schema, indent=2, sort_keys=True) + "\n")
    return 0


def main():
    ap = argparse.ArgumentParser(
        description="Generate RouterOS switch configuration scripts."
    )
    sub = ap.add_subparsers(dest="command")
    sub.required = True

    sub.add_parser("generate", help="JSON stdin -> .rsc stdout")

    sp_learn = sub.add_parser(
        "learn-schema",
        help="Read the device's own property schema and print it as JSON. "
             "Commit the result; `generate` refuses to emit a script "
             "naming a property the schema doesn't have.",
    )
    sp_learn.add_argument("ssh", help="SSH endpoint (user@host).")
    sp_learn.add_argument("--ssh-args", default="",
                          help="Extra SSH options as one string.")

    args = ap.parse_args()

    if args.command == "generate":
        config = json.load(sys.stdin)
        # Check property names before emitting anything. This script is
        # what `deploy` feeds to run-after-reset, and a bad property
        # halts the import *after* the wipe — the switch is already
        # empty by the time anything notices. RouterOS won't pre-check
        # for us: `:parse` accepts unbalanced braces, unknown menus and
        # unknown properties alike. Failing here is the only chance to
        # fail before the destructive step.
        problems = schema_violations(load_schema())
        if problems:
            sys.stderr.write("refusing to generate — unknown properties:\n")
            for p in problems:
                sys.stderr.write(f"  {p}\n")
            return 1
        sys.stdout.write(generate(config))
    elif args.command == "learn-schema":
        return cmd_learn_schema(args)
    else:
        raise SystemExit(f"unhandled command {args.command!r}")


if __name__ == "__main__":
    sys.exit(main() or 0)
