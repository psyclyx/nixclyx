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
# One declarative table per record section drives what used to be three
# hand-written, must-stay-in-lockstep encodings of every field: the full
# emitter (generate), the spec→diff projection (_desired_diffable), and
# the diff comparison metadata (_IDENTITY / _COMPARE_FIELDS). Add a field
# once, here, and it flows to all three.
#
#   omit:  "req"    always emit (identity / mandatory)
#          "none"   skip when the python value is None (0 / "" still emit)
#          "falsy"  skip when the python value is falsy
#   kind:  "raw"    value verbatim
#          "int"    str(value)
#          "bool"   True→yes  False→no
#          "flag"   emit `key=yes` when truthy, else skip entirely
#          "qstr"   always double-quoted (comments)
#          "list"   comma-joined
#   diffable=False  emitted by generate() but ignored by the diff (e.g.
#                   RouterOS never exports it, so comparing churns).


class Field:
    __slots__ = ("py", "ros", "kind", "omit", "diffable")

    def __init__(self, py, ros=None, kind="raw", omit="none", diffable=True):
        self.py = py
        self.ros = ros if ros is not None else py.replace("_", "-")
        self.kind = kind
        self.omit = omit
        self.diffable = diffable

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

    def diff_value(self, entry):
        """py-keyed entry → canonical string for the diff params dict
        (ros-keyed, unquoted — the diff formatter re-quotes), or None."""
        v = entry.get(self.py)
        if self._skip(v):
            return None
        if self.kind == "bool":
            return "yes" if v else "no"
        if self.kind == "flag":
            return "yes"
        if self.kind == "list":
            return _comma_list(v)
        return str(v)


F = Field

# Record sections: config-key → (rsc section header, comment, identity
# tuple (None = not diffed), field list). Order of fields is the emit
# order and must match `/export` field order for a clean diff.
_ROUTE_FIELDS = [
    F("disabled", kind="flag"),
    F("dst", "dst-address", omit="req"), F("gateway", omit="req"),
    F("distance", kind="int"), F("routing_table", "routing-table", omit="falsy"),
    F("scope", kind="int"), F("target_scope", "target-scope", kind="int"),
    F("pref_src", "pref-src", omit="falsy"),
    F("comment", kind="qstr", omit="falsy"),
]

RECORD_SECTIONS = [
    ("vlan_interfaces", "/interface vlan", "# ── VLAN interfaces ──",
     ("name",), [
        F("interface", omit="req"), F("name", omit="req"),
        F("vlan_id", "vlan-id", kind="int", omit="req"),
        F("mtu", kind="int"), F("comment", kind="qstr", omit="falsy")]),
    ("addresses", "/ip address", "# ── IP addresses ──",
     ("address",), [
        F("address", omit="req"), F("interface", omit="req"),
        F("network", omit="falsy"), F("comment", kind="qstr", omit="falsy")]),
    ("routes", "/ip route", "# ── Routes ──", None, _ROUTE_FIELDS),
    # DHCP relay. Diffable (identity = name) so relays can be added to a
    # live switch without a reboot: the relay only adds a unicast path to
    # the server, it never removes the existing broadcast one, so a client
    # that already reaches DHCP by flooding is unaffected while one that
    # doesn't starts working.
    ("dhcp_relays", "/ip dhcp-relay", "# ── DHCP relay ──",
     ("name",), [
        F("name", omit="req"), F("interface", omit="req"),
        F("dhcp_server", "dhcp-server", kind="list", omit="req"),
        F("local_address", "local-address", omit="falsy"),
        F("disabled", kind="bool"),
        F("comment", kind="qstr", omit="falsy")]),
    ("ipv6_addresses", "/ipv6 address", "# ── IPv6 addresses ──",
     ("address",), [
        F("address", omit="req"), F("interface", omit="req"),
        F("advertise", kind="bool"),
        F("eui64", "eui-64", kind="bool", diffable=False),
        F("no_dad", "no-dad", kind="bool"),
        F("comment", kind="qstr", omit="falsy")]),
    ("ipv6_nd", "/ipv6 nd", "# ── IPv6 ND ──",
     ("interface",), [
        F("interface", omit="req"), F("ra_lifetime", "ra-lifetime"),
        F("comment", kind="qstr", omit="falsy")]),
    ("ipv6_routes", "/ipv6 route", "# ── IPv6 routes ──", None, _ROUTE_FIELDS),
]

_SECTION_BY_PATH = {path: (fields, ident) for _, path, _, ident, fields
                    in RECORD_SECTIONS}


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


def _diff_params(fields, entry):
    """py-keyed entry + schema → the ros-keyed params dict the diff
    machinery compares (skips non-diffable and omitted fields)."""
    out = {}
    for f in fields:
        if not f.diffable:
            continue
        v = f.diff_value(entry)
        if v is not None:
            out[f.ros] = v
    return out


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
        if snmp.get("community"):
            parts.append(f'community={snmp["community"]}')
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
        _SECTION_BY_PATH["/interface vlan"][0], vlan_ifaces)

    # ── L3 hardware offloading ─────────────────────────────────
    # Two distinct knobs land here:
    #   system.l3_hw_offload (bool) — enables bridge-level inter-VLAN
    #     routing offload on Marvell Prestera chipsets (CRS3xx, RouterOS
    #     7.6+). Maps to `/interface bridge settings set l3-hw-offloading=yes`.
    #   l3hw_settings.* (dict) — fine-grained switch-chip L3 knobs
    #     (IPv6 hardware path, ICMP reply behavior). Maps to
    #     `/interface ethernet switch l3hw-settings set ...`.
    if system.get("l3_hw_offload"):
        lines.append("# ── Bridge L3 hardware offloading ──")
        lines.append(
            "/interface bridge settings set l3-hw-offloading=yes"
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
        _SECTION_BY_PATH["/ip address"][0], addresses)

    # ── Routes ──────────────────────────────────────────────────
    _emit_record_section(
        lines, "/ip route", "# ── Routes ──",
        _SECTION_BY_PATH["/ip route"][0], routes)

    # ── DHCP relay ─────────────────────────────────────────────
    # Emitted after /ip address so the local-address it references is
    # already on the box.
    _emit_record_section(
        lines, "/ip dhcp-relay", "# ── DHCP relay ──",
        _SECTION_BY_PATH["/ip dhcp-relay"][0], dhcp_relays)

    # ── IPv6 addresses ─────────────────────────────────────────
    _emit_record_section(
        lines, "/ipv6 address", "# ── IPv6 addresses ──",
        _SECTION_BY_PATH["/ipv6 address"][0], addresses6)

    # ── IPv6 ND (per-interface RA overrides) ───────────────────
    # RouterOS defaults to advertising every SVI with a global v6
    # address as an IPv6 default router (ra-lifetime>0). On interfaces
    # where the switch is transit-only (it has its own gateway there),
    # that makes hosts blackhole internet v6 through it. A per-interface
    # entry with ra-lifetime=none keeps SLAAC prefix advertisement but
    # stops the switch claiming to be a default router.
    _emit_record_section(
        lines, "/ipv6 nd", "# ── IPv6 ND ──",
        _SECTION_BY_PATH["/ipv6 nd"][0], nd6)

    # ── IPv6 routes ────────────────────────────────────────────
    _emit_record_section(
        lines, "/ipv6 route", "# ── IPv6 routes ──",
        _SECTION_BY_PATH["/ipv6 route"][0], routes6)

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


# ── Diff machinery ────────────────────────────────────────────────────
#
# Pull current state via `/export terse` over SSH, parse into the same
# shape we emit, compute the delta, push only the changed items.
# Non-destructive — runs in safe-mode so a broken SSH session reverts.
#
# Scope: only sections where adding/removing items mid-flight is safe
# (`/interface vlan`, `/ip address`, `/interface bridge vlan`). Other
# sections (system, bridge ports, bonds, ssh keys) are deploy-once and
# don't churn; if those differ between the spec and the switch we
# print a warning and leave them.


_KV_RE = None
_QUOTED_RE = None


def _kv_split(rest):
    """Parse `key=value key2="quoted value" key3=a,b,c` into a dict."""
    import re
    out = {}
    # Tokenize: handles unquoted, double-quoted, and bracketed [find ...] values.
    pat = re.compile(
        r'([a-zA-Z0-9_.-]+)='
        r'(?:"([^"]*)"|\[([^\]]*)\]|(\S+))'
    )
    for m in pat.finditer(rest):
        key = m.group(1)
        val = m.group(2) if m.group(2) is not None else \
              ("[" + m.group(3) + "]") if m.group(3) is not None else \
              m.group(4)
        out[key] = val
    return out


def parse_export(text):
    """Parse `/export terse` output into a dict keyed by section path.

    Each section value is a list of `(action, params_dict)` tuples.
    Lines beginning with `#` and blank lines are skipped.
    """
    sections = {}
    current_section = None

    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue

        # Action keywords that appear at the start of a command line.
        actions = ("add ", "set ", "remove ")

        if line.startswith("/"):
            # `/path action ...` form (single-line section + command), or
            # `/path` form (section header only).
            for kw in actions:
                idx = line.find(" " + kw.strip() + " ")
                # Don't match keyword as path component — only after a space.
                if idx > 0:
                    section = line[:idx]
                    rest = line[idx + 1:]
                    action_word, _, params = rest.partition(" ")
                    sections.setdefault(section, []).append(
                        (action_word, _kv_split(params))
                    )
                    current_section = section
                    break
            else:
                # `/path` only — start of a multi-line section block.
                current_section = line
                sections.setdefault(current_section, [])
        elif current_section is not None:
            # Continuation within a section.
            for kw in actions:
                if line.startswith(kw):
                    action_word = kw.strip()
                    params = line[len(kw):]
                    sections[current_section].append(
                        (action_word, _kv_split(params))
                    )
                    break

    return sections


# Bridge VLAN table — structural in generate() (nested in the bridge
# block), but diffed here, so its schema lives alongside the diff.
_BRIDGE_VLAN_FIELDS = [
    F("bridge", omit="req"), F("vlan_ids", "vlan-ids", omit="req"),
    F("tagged", kind="list", omit="falsy"),
    F("untagged", kind="list", omit="falsy"),
]

# Per-section identity + comparable fields for diffing. Record sections
# derive straight from the schema (identity is None → generate-only, not
# diffed, e.g. routes). Switch-chip / singleton rows are hardware-rooted
# `set [find …]` sections handled specially in diff_state.
_IDENTITY = {}
_COMPARE_FIELDS = {}
for _key, _path, _c, _ident, _fields in RECORD_SECTIONS:
    if _ident is None:
        continue
    _IDENTITY[_path] = _ident
    _COMPARE_FIELDS[_path] = tuple(f.ros for f in _fields if f.diffable)

_IDENTITY["/interface bridge vlan"] = ("vlan-ids",)
_COMPARE_FIELDS["/interface bridge vlan"] = tuple(
    f.ros for f in _BRIDGE_VLAN_FIELDS if f.diffable)

_IDENTITY.update({
    "/interface ethernet switch": ("name",),
    "/interface ethernet switch l3hw-settings": ("_singleton",),
    "/ipv6 settings": ("_singleton",),
})
_COMPARE_FIELDS.update({
    "/interface ethernet switch": ("name", "l3-hw-offloading", "qos-hw-offloading"),
    "/interface ethernet switch l3hw-settings": (
        "_singleton", "ipv6-hw", "icmp-reply-on-error",
    ),
    "/ipv6 settings": (
        "_singleton", "forward", "accept-redirects", "accept-source-route",
    ),
})

# Sections that are configured via `set [find ...]` against existing
# entries (the hardware row already exists; we can't `add` or `remove`
# it, only `set`). Diff still computes deltas but emits a `set` op
# instead of add/remove.
_SET_ONLY = {
    "/interface ethernet switch",
    "/interface ethernet switch l3hw-settings",
    "/ipv6 settings",
}

# Singleton sections render as plain `set ipv6-hw=yes ...` (no
# [find ...] selector — the row is implicit / chip-rooted).
_SINGLETON = {
    "/interface ethernet switch l3hw-settings",
    "/ipv6 settings",
}


def _normalize_list(s):
    """Normalize comma-separated lists for comparison (sort, dedupe)."""
    if s is None or s == "":
        return ""
    parts = sorted(set(p.strip() for p in s.split(",") if p.strip()))
    return ",".join(parts)


_DEFAULT_VALUES = {
    "/interface vlan": {
        # RouterOS omits these from /export when they equal the default.
        "mtu": "1500",
    },
}


def _canon_field(section, key, val):
    """Canonicalize a field value so the spec form and the `/export
    terse` form compare equal. RouterOS omits the default /64 prefix on
    `/ipv6 address` export (`.../64` → bare address), so strip it from
    the spec side — otherwise every SVI address diffs as changed and the
    apply churns (remove + re-add) all of them."""
    if val is None:
        return None
    if section == "/ipv6 address" and key == "address" and val.endswith("/64"):
        return val[:-len("/64")]
    return val


def _normalize_entry(section, entry):
    """Project an entry down to comparable fields, normalize list values.

    Missing field treated as field's RouterOS default (see _DEFAULT_VALUES)
    so a spec that explicitly states the default doesn't diff against an
    exported state that omits it.
    """
    fields = _COMPARE_FIELDS.get(section, ())
    defaults = _DEFAULT_VALUES.get(section, {})
    out = {}
    for f in fields:
        v = entry.get(f)
        if v is None and f in defaults:
            v = defaults[f]
        if f in ("tagged", "untagged") and v is not None:
            v = _normalize_list(v)
        out[f] = _canon_field(section, f, v)
    return out


def _index_section(section, entries):
    """Map identity-tuple → normalized entry for one section's entries.
    For sections in _SET_ONLY, both `set` and pre-existing rows count;
    everywhere else we only index `add` lines (they create new objects).
    """
    keys = _IDENTITY.get(section)
    if keys is None:
        return {}
    valid_actions = {"add", "set"} if section in _SET_ONLY else {"add"}
    out = {}
    for action, params in entries:
        if action not in valid_actions:
            continue
        ident = tuple(_canon_field(section, k, params.get(k)) for k in keys)
        if any(v is None for v in ident):
            continue
        out[ident] = _normalize_entry(section, params)
    return out


def _desired_diffable(config):
    """Extract diffable sections from JSON spec into the same shape as
    parse_export's output (a dict of section→list of (action, params))."""
    bridge = config.get("bridge", {})
    bridge_name = bridge.get("name", "bridge1")
    system = config.get("system", {})

    sections = {path: [] for path in _IDENTITY}

    # Switch chip — l3-hw-offloading lives here. CRS3xx has a Marvell
    # "switch1" plus auxiliary chips; the L3 setting goes on the
    # primary (Marvell). We can't know the name without reading export
    # state, so default to "switch1" matching what the platform names
    # the primary. Operators can override via system.switches.
    sections["/interface ethernet switch l3hw-settings"] = []
    if system.get("l3_hw_offload"):
        sections["/interface ethernet switch"].append(("set", {
            "name": "switch1",
            "l3-hw-offloading": "yes",
        }))

    # Per-chip L3 hw sub-settings (ipv6-hw, icmp-reply-on-error).
    # Singleton row — no identity column on the device.
    l3hw = config.get("l3hw_settings", {})
    if l3hw:
        params = {"_singleton": "*"}
        if l3hw.get("ipv6_hw") is not None:
            params["ipv6-hw"] = "yes" if l3hw["ipv6_hw"] else "no"
        if l3hw.get("icmp_reply_on_error") is not None:
            params["icmp-reply-on-error"] = (
                "yes" if l3hw["icmp_reply_on_error"] else "no"
            )
        sections["/interface ethernet switch l3hw-settings"].append(
            ("set", params)
        )

    # /ipv6 settings — singleton software-level v6 stack config.
    ipv6 = config.get("ipv6_settings", {})
    if ipv6:
        params = {"_singleton": "*"}
        if ipv6.get("forwarding") is not None:
            params["forward"] = "yes" if ipv6["forwarding"] else "no"
        if ipv6.get("accept_redirects") is not None:
            params["accept-redirects"] = (
                "yes" if ipv6["accept_redirects"] else "no"
            )
        if ipv6.get("accept_source_route") is not None:
            params["accept-source-route"] = (
                "yes" if ipv6["accept_source_route"] else "no"
            )
        sections["/ipv6 settings"].append(("set", params))

    # Record sections → ("add", {ros-key: value}) straight from the
    # schema. Sections with identity=None (routes) are generate-only.
    for key, path, _c, ident, fields in RECORD_SECTIONS:
        if ident is None:
            continue
        for entry in config.get(key, []):
            sections[path].append(("add", _diff_params(fields, entry)))

    for bv in bridge.get("vlans", []):
        entry = dict(bv, bridge=bridge_name)
        sections["/interface bridge vlan"].append(
            ("add", _diff_params(_BRIDGE_VLAN_FIELDS, entry)))

    return sections


def _format_find(section, ident):
    """RouterOS `[find <key>=<value> ...]` selector for an entry."""
    keys = _IDENTITY[section]
    parts = [f"{k}={v}" for k, v in zip(keys, ident)]
    return "[find " + " ".join(parts) + "]"


def _fmt_val(v):
    """Render an rsc `key=value` value token. Quote when the value is
    empty or contains whitespace (e.g. `comment="a b"`); leave bare
    tokens like `ra-lifetime=none` unquoted."""
    s = "" if v is None else str(v)
    if s == "" or any(c.isspace() for c in s):
        return f'"{s}"'
    return s


def _format_add(params):
    return "add " + " ".join(f"{k}={_fmt_val(v)}" for k, v in params.items())


def _format_set(section, ident, changed):
    if section in _SINGLETON:
        # No selector — settings are chip-rooted singletons.
        return "set " + " ".join(
            f"{k}={_fmt_val(v)}" for k, v in changed.items()
        )
    return f"set {_format_find(section, ident)} " + " ".join(
        f"{k}={_fmt_val(v)}" for k, v in changed.items()
    )


def _format_remove(section, ident):
    return f"remove {_format_find(section, ident)}"


def diff_state(current, desired):
    """Compute add/set/remove operations per diffable section.

    Returns dict: section → list of rsc command strings (no section
    header). Sections with no ops are omitted.
    """
    ops = {}
    for section in _IDENTITY:
        cur_idx = _index_section(section, current.get(section, []))
        des_idx = _index_section(section, desired.get(section, []))

        cur_keys = set(cur_idx.keys())
        des_keys = set(des_idx.keys())

        section_ops = []

        # Adds: in desired, not current.
        # For set-only sections, the row already exists on the device
        # (hardware-rooted), so we emit a `set` instead of `add`. Treat
        # any present-in-desired-only as a set operation that imports
        # all comparable fields.
        for ident in sorted(des_keys - cur_keys):
            entry = des_idx[ident]
            if section in _SET_ONLY:
                changed = {
                    k: (v if v is not None else "")
                    for k, v in entry.items()
                    if k not in _IDENTITY[section] and v is not None
                }
                if changed:
                    section_ops.append(_format_set(section, ident, changed))
            else:
                cleaned = {k: v for k, v in entry.items() if v is not None}
                section_ops.append(_format_add(cleaned))

        # Sets: in both but content differs. Only emit changed fields.
        for ident in sorted(cur_keys & des_keys):
            cur_entry = cur_idx[ident]
            des_entry = des_idx[ident]
            changed = {}
            for k in _COMPARE_FIELDS[section]:
                if k in _IDENTITY[section]:
                    continue
                if cur_entry.get(k) != des_entry.get(k):
                    new_val = des_entry.get(k) or ""
                    changed[k] = new_val
            if changed:
                section_ops.append(_format_set(section, ident, changed))

        # Removes: in current, not desired. Skipped for set-only
        # sections (hardware-rooted rows can't be removed).
        if section not in _SET_ONLY:
            for ident in sorted(cur_keys - des_keys):
                section_ops.append(_format_remove(section, ident))

        if section_ops:
            ops[section] = section_ops

    return ops


def format_diff_script(ops, identity=None):
    """Render an ops dict (as returned by diff_state) as an rsc script."""
    if not ops:
        return ""
    lines = []
    if identity:
        lines.append(f"# Incremental diff for {identity}")
        lines.append("# Generated from spec → current-state delta.")
        lines.append("")
    for section in sorted(ops.keys()):
        lines.append(section)
        for cmd in ops[section]:
            lines.append(cmd)
        lines.append("")
    return "\n".join(lines)


# ── CLI ──────────────────────────────────────────────────────────────


def cmd_diff(args):
    """Emit an .rsc diff: spec from stdin, current-state .rsc from a file."""
    config = json.load(sys.stdin)
    with open(args.current) as f:
        current_text = f.read()
    current = parse_export(current_text)
    desired = _desired_diffable(config)
    ops = diff_state(current, desired)

    if not ops:
        sys.stderr.write("# already in sync; no operations.\n")
        return 0

    script = format_diff_script(
        ops, identity=config.get("system", {}).get("identity")
    )
    sys.stdout.write(script)
    return 0


# ── Commit-confirm rollback ────────────────────────────────────────────
#
# A live apply can strand the operator (the SSH path may ride the very
# switch being changed). So the apply ARMS a self-firing revert on the
# device before touching anything: it snapshots the current config to a
# backup and schedules `backup load` (a reboot-to-revert) after N minutes.
# Silence → revert. Only an explicit `confirm` (run after verifying the
# change is good) cancels the timer. The arming runs at the TOP of the
# imported script, so even a change that kills SSH mid-import is covered.


def _rollback_names(session_id):
    return f"preflight-{session_id}", f"rollback-{session_id}"


def _arm_preamble(session_id, minutes):
    """rsc preamble that snapshots config and arms the timed revert."""
    backup, sched = _rollback_names(session_id)
    return "\n".join([
        f"# ── commit-confirm: auto-revert in {minutes}m unless confirmed ──",
        f"/system backup save name={backup} dont-encrypt=yes",
        f":do {{ /system scheduler remove [find name={sched}] }} on-error={{}}",
        (f"/system scheduler add name={sched} interval={minutes}m "
         f'on-event="/system backup load name={backup}"'),
        "",
        "",
    ])


def _ssh(args, remote_cmd, **kw):
    import shlex
    import subprocess
    ssh_extra = shlex.split(args.ssh_args) if args.ssh_args else []
    return subprocess.run(
        ["ssh", "-o", "BatchMode=yes", *ssh_extra, args.ssh, remote_cmd],
        capture_output=True, text=True, **kw,
    )


def cmd_confirm(args):
    """Cancel the armed rollback — the commit half of commit-confirm."""
    backup, sched = _rollback_names(args.session_id)
    cmd = (f":do {{ /system scheduler remove [find name={sched}] }} on-error={{}}; "
           f":do {{ /file remove [find name={backup}.backup] }} on-error={{}}")
    r = _ssh(args, cmd, timeout=30)
    sys.stderr.write(r.stderr)
    sys.stdout.write(r.stdout)
    if r.returncode != 0:
        sys.stderr.write("confirm FAILED — rollback still armed (will fire!).\n")
        return r.returncode
    sys.stderr.write(f"Committed: cancelled {sched}, removed {backup}.backup.\n")
    return 0


def cmd_rollback(args):
    """Trigger the revert now (reboots the switch to the preflight backup)."""
    backup, _ = _rollback_names(args.session_id)
    sys.stderr.write(f"Reverting to {backup} (switch will reboot)...\n")
    # `backup load` reboots, so the SSH session drops — a nonzero exit here
    # is expected and not an error.
    _ssh(args, f"/system backup load name={backup}", timeout=30)
    sys.stderr.write("Revert triggered; switch rebooting.\n")
    return 0


def cmd_apply(args):
    """Pull state via SSH, compute diff, push it back.

    SSH options are passed through after `--` (e.g. `-J jumphost`).
    """
    import subprocess
    import tempfile

    import shlex
    config = json.load(sys.stdin)
    ssh_endpoint = args.ssh
    ssh_extra = shlex.split(args.ssh_args) if args.ssh_args else []

    # 1. Pull current state via /export terse.
    sys.stderr.write(f"Pulling current state from {ssh_endpoint}...\n")
    pull = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", *ssh_extra, ssh_endpoint, "/export terse"],
        capture_output=True, text=True, timeout=30,
    )
    if pull.returncode != 0:
        sys.stderr.write(f"ssh failed: {pull.stderr}\n")
        return pull.returncode

    current = parse_export(pull.stdout)
    desired = _desired_diffable(config)
    ops = diff_state(current, desired)

    if not ops:
        sys.stderr.write("Already in sync; nothing to apply.\n")
        return 0

    script = format_diff_script(
        ops, identity=config.get("system", {}).get("identity")
    )

    # Arm the self-firing revert at the TOP of the script, before any change
    # — so even a change that severs SSH mid-import is still covered.
    arm = args.rollback_timeout > 0
    if arm:
        script = _arm_preamble(args.session_id, args.rollback_timeout) + script

    op_count = sum(len(v) for v in ops.values())
    sys.stderr.write(f"Computed {op_count} operation(s) across "
                     f"{len(ops)} section(s):\n")
    for section, cmds in ops.items():
        sys.stderr.write(f"  {section}: {len(cmds)}\n")

    if args.dry_run:
        sys.stderr.write("\n--- dry-run: would apply ---\n")
        sys.stdout.write(script)
        return 0

    # 2. SCP the diff script.
    fname = f"diff-{args.session_id}.rsc"
    with tempfile.NamedTemporaryFile("w", suffix=".rsc", delete=False) as tf:
        tf.write(script)
        tmp_path = tf.name

    sys.stderr.write(f"\nUploading {fname}...\n")
    scp = subprocess.run(
        ["scp", "-o", "BatchMode=yes", *ssh_extra, tmp_path,
         f"{ssh_endpoint}:/{fname}"],
        timeout=30,
    )
    if scp.returncode != 0:
        sys.stderr.write("scp failed.\n")
        return scp.returncode

    # 3. Run /import. Failure on any command logs an error but RouterOS
    # carries on; we check the system log afterwards.
    sys.stderr.write(f"Importing {fname}...\n")
    imp = subprocess.run(
        ["ssh", "-o", "BatchMode=yes", *ssh_extra, ssh_endpoint,
         f"/import file={fname}"],
        capture_output=True, text=True, timeout=60,
    )
    sys.stdout.write(imp.stdout)
    sys.stderr.write(imp.stderr)
    if imp.returncode != 0:
        sys.stderr.write("/import failed.\n")
        return imp.returncode

    if arm:
        _, sched = _rollback_names(args.session_id)
        ssh_args_flag = f' --ssh-args "{args.ssh_args}"' if args.ssh_args else ""
        sys.stderr.write(
            f"\n⚠  ROLLBACK ARMED — {args.ssh} auto-reverts (reboots) in "
            f"{args.rollback_timeout}m unless confirmed.\n"
            f"   Verify connectivity/health, THEN commit:\n"
            f"     routeros-config confirm {args.ssh}{ssh_args_flag} "
            f"--session-id {args.session_id}\n"
            f"   Or revert now:\n"
            f"     routeros-config rollback {args.ssh}{ssh_args_flag} "
            f"--session-id {args.session_id}\n"
        )
    else:
        sys.stderr.write("Done (no rollback armed).\n")
    return 0


def main():
    ap = argparse.ArgumentParser(
        description="Generate RouterOS switch configuration scripts."
    )
    sub = ap.add_subparsers(dest="command")
    sub.required = True

    sub.add_parser("generate", help="JSON stdin -> .rsc stdout")

    sp_diff = sub.add_parser(
        "diff",
        help="JSON stdin + current-state file -> diff .rsc stdout"
    )
    sp_diff.add_argument("--current", required=True,
                         help="Path to current-state file (output of `/export terse`).")

    sp_apply = sub.add_parser(
        "apply",
        help="JSON stdin + SSH endpoint -> pull current, diff, push."
    )
    sp_apply.add_argument("ssh", help="SSH endpoint (user@host).")
    sp_apply.add_argument("--ssh-args", default="",
                          help="Extra SSH options as one string (e.g. \"-J jumphost\").")
    sp_apply.add_argument("--dry-run", action="store_true",
                          help="Print the diff script instead of applying it.")
    sp_apply.add_argument("--session-id", default="cli",
                          help="Session identifier for the uploaded filename + rollback names.")
    sp_apply.add_argument("--rollback-timeout", type=int, default=3, metavar="MIN",
                          help="Arm a self-firing revert that reboots to the pre-apply "
                               "config after MIN minutes unless `confirm`ed. 0 disables.")

    for name, helptext in [
        ("confirm", "Cancel the armed rollback (commit the last apply)."),
        ("rollback", "Trigger the revert now (reboots to the preflight backup)."),
    ]:
        sp = sub.add_parser(name, help=helptext)
        sp.add_argument("ssh", help="SSH endpoint (user@host).")
        sp.add_argument("--ssh-args", default="",
                        help="Extra SSH options as one string (e.g. \"-J jumphost\").")
        sp.add_argument("--session-id", default="cli",
                        help="Session identifier matching the apply to confirm/revert.")

    args = ap.parse_args()

    if args.command == "generate":
        config = json.load(sys.stdin)
        sys.stdout.write(generate(config))
    elif args.command == "diff":
        return cmd_diff(args)
    elif args.command == "apply":
        return cmd_apply(args)
    elif args.command == "confirm":
        return cmd_confirm(args)
    elif args.command == "rollback":
        return cmd_rollback(args)


if __name__ == "__main__":
    sys.exit(main() or 0)
