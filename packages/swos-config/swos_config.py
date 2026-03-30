#!/usr/bin/env python3
"""swos-config: Generate and parse MikroTik SwOS switch backup files.

Supports the .swb text backup format used by CSS326 and other SwOS devices.

Usage:
    swos-config generate < config.json > backup.swb
    swos-config parse < backup.swb > config.json
"""

import argparse
import json
import sys


# ── SwB text format parser ──────────────────────────────────────────


class _Parser:
    """Recursive descent parser for the SwOS .swb text format.

    Grammar:
        file    = section (',' section)*
        section = name ':' value
        value   = object | array | number | string
        object  = '{' (key ':' value (',' key ':' value)*)? '}'
        array   = '[' (value (',' value)*)? ']'
        number  = '0x' [0-9a-fA-F]+
        string  = "'" [^']* "'"
    """

    def __init__(self, text):
        self.t = text
        self.i = 0

    def file(self):
        sections = {}
        while self.i < len(self.t):
            name = self._read_until(":")
            self._expect(":")
            val = self._value()
            sections[name] = val
            if self.i < len(self.t) and self.t[self.i] == ",":
                self.i += 1
        return sections

    def _value(self):
        c = self.t[self.i]
        if c == "{":
            return self._object()
        if c == "[":
            return self._array()
        if c == "'":
            return self._string()
        if c == "0":
            return self._number()
        raise ValueError(
            f"unexpected {c!r} at pos {self.i}: ...{self.t[self.i:self.i+20]}..."
        )

    def _object(self):
        self._expect("{")
        d = {}
        first = True
        while self.t[self.i] != "}":
            if not first:
                self._expect(",")
            first = False
            key = self._read_until(":")
            self._expect(":")
            d[key] = self._value()
        self._expect("}")
        return d

    def _array(self):
        self._expect("[")
        a = []
        first = True
        while self.t[self.i] != "]":
            if not first:
                self._expect(",")
            first = False
            a.append(self._value())
        self._expect("]")
        return a

    def _string(self):
        self._expect("'")
        start = self.i
        while self.t[self.i] != "'":
            self.i += 1
        s = self.t[start : self.i]
        self.i += 1
        return s

    def _number(self):
        start = self.i
        self.i += 2  # skip 0x
        while self.i < len(self.t) and self.t[self.i] in "0123456789abcdefABCDEF":
            self.i += 1
        return int(self.t[start : self.i], 16)

    def _read_until(self, stop):
        start = self.i
        while self.t[self.i] != stop:
            self.i += 1
        return self.t[start : self.i]

    def _expect(self, ch):
        if self.t[self.i] != ch:
            raise ValueError(
                f"expected {ch!r} at pos {self.i}, got {self.t[self.i]!r}"
            )
        self.i += 1


def _parse_swb(text):
    """Parse a .swb text file into a dict of section_name -> parsed value."""
    return _Parser(text.strip()).file()


# ── SwB text format serializer ──────────────────────────────────────

SECTION_ORDER = [
    "vlan.b", "lacp.b", ".pwd.b", "snmp.b", "rstp.b",
    "link.b", "fwd.b", "sys.b", "acl.b", "host.b",
]


def _hex(n):
    """Integer to SwB hex literal with appropriate width."""
    if n <= 0xFF:
        return f"0x{n:02x}"
    if n <= 0xFFFF:
        return f"0x{n:04x}"
    return f"0x{n:08x}"


def _ser_val(v):
    if isinstance(v, dict):
        return "{" + ",".join(f"{k}:{_ser_val(x)}" for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "[" + ",".join(_ser_val(x) for x in v) + "]"
    if isinstance(v, int):
        return _hex(v)
    if isinstance(v, str):
        return f"'{v}'"
    raise TypeError(f"cannot serialize {type(v)}")


def _serialize_swb(raw):
    """Serialize a raw sections dict back to .swb text."""
    parts = []
    for name in SECTION_ORDER:
        if name in raw:
            parts.append(f"{name}:{_ser_val(raw[name])}")
    return ",".join(parts) + "\n"


# ── Encoding helpers ────────────────────────────────────────────────


def _hex_decode(s):
    """Hex-encoded ASCII -> text. Empty string if empty."""
    return bytes.fromhex(s).decode("ascii", errors="replace") if s else ""


def _hex_encode(s):
    """Text -> hex-encoded ASCII. Empty string if empty."""
    return s.encode("ascii").hex() if s else ""


def _le_ip_decode(val):
    """Little-endian uint32 -> dotted-quad IPv4."""
    return ".".join(str((val >> (i * 8)) & 0xFF) for i in range(4))


def _le_ip_encode(ip):
    """Dotted-quad IPv4 -> little-endian uint32."""
    p = [int(x) for x in ip.split(".")]
    return p[0] | (p[1] << 8) | (p[2] << 16) | (p[3] << 24)


def _mask_to_ports(val, n):
    """Bitmask -> sorted list of 1-based port numbers."""
    return sorted(i + 1 for i in range(n) if val & (1 << i))


def _ports_to_mask(ports):
    """List of 1-based port numbers -> bitmask."""
    return sum(1 << (p - 1) for p in ports)


def _bit(val, i):
    """Test bit i in val."""
    return bool(val & (1 << i))


def _bool_mask(ports, n, field):
    """Build bitmask from per-port boolean field."""
    return _ports_to_mask([i + 1 for i in range(n) if ports[i][field]])


# ── Decode: raw .swb sections -> JSON config ────────────────────────


def _decode(raw):
    link = raw["link.b"]
    fwd = raw["fwd.b"]
    sys_ = raw["sys.b"]
    lacp = raw["lacp.b"]

    n = len(link["spdc"])  # port count

    ports = []
    for i in range(n):
        ports.append({
            "auto_negotiate": _bit(link["an"], i),
            "blocked": _bit(link.get("blkp", 0), i),
            "cable_mode": link["cm"][i],
            "default_vid": fwd["dvid"][i],
            "duplex": _bit(link["dpxc"], i),
            "enabled": _bit(link["en"], i),
            "flow_control_rx": _bit(link.get("fctr", 0), i),
            "flow_control_tx": _bit(link["fctc"], i),
            "forward_multicast": _bit(fwd["fmc"], i),
            "forward_to": _mask_to_ports(fwd[f"fp{i + 1}"], n),
            "ingress_rate": fwd["ir"][i],
            "input_mirror": _bit(fwd.get("imr", 0), i),
            "lacp_group": lacp["sgrp"][i],
            "lacp_mode": lacp["mode"][i],
            "mac_lock": _bit(fwd.get("lck", 0), i),
            "mac_lock_filter": _bit(fwd.get("lckf", 0), i),
            "name": _hex_decode(link["nm"][i]),
            "output_mirror": _bit(fwd.get("omr", 0), i),
            "qos_type": link["qtyp"][i],
            "sfp": bool(link["sfpr"][i]),
            "source_unknown": _bit(fwd.get("suni", 0), i),
            "speed": link["spdc"][i],
            "storm_rate": fwd["srt"][i],
            "vlan_mode": fwd["vlan"][i],
            "vlan_receive": fwd["vlni"][i],
        })

    vlans = []
    for v in raw["vlan.b"]:
        vlans.append({
            "id": v["vid"],
            "igmp": bool(v["igmp"]),
            "learning": bool(v["lrn"]),
            "members": _mask_to_ports(v["mbr"], n),
            "mirror": bool(v.get("mrr", 0)),
            "name": _hex_decode(v["nm"]),
            "port_isolation": bool(v["piso"]),
        })

    system = {
        "admin_vlan": sys_["avln"],
        "all_ports": _mask_to_ports(sys_["allp"], n),
        "allow_from_all_addresses": bool(sys_["alla"]),
        "allow_from_all_mgmt": bool(sys_["allm"]),
        "auto_info": bool(sys_["ainf"]),
        "discovery": bool(sys_["dsc"]),
        "drop_tagged": _mask_to_ports(sys_["dtrp"], n),
        "frame_size_check": bool(sys_["frmc"]),
        "identity": _hex_decode(sys_["id"]),
        "igmp_flood": bool(sys_["igfl"]),
        "igmp_query": bool(sys_["igmq"]),
        "igmp_snooping": bool(sys_["igmp"]),
        "igmp_vlan_exclusive": bool(sys_["igve"]),
        "ip": _le_ip_decode(sys_["ip"]),
        "ip_type": sys_["iptp"],
        "ivl": bool(sys_["ivl"]),
        "management": bool(sys_["mgmt"]),
        "poe": bool(sys_["poe"]),
        "port_discovery": _mask_to_ports(sys_["pdsc"], n),
        "stp_cost_mode": sys_["cost"],
        "stp_priority": sys_["prio"],
        "watchdog": bool(sys_["wdt"]),
    }

    return {
        "acl": raw.get("acl.b", []),
        "filter_vid": fwd.get("fvid", 0),
        "hosts": raw.get("host.b", []),
        "mirror": {"target_port": fwd.get("mrto", 0)},
        "password": _hex_decode(raw[".pwd.b"]["pwd"]),
        "ports": ports,
        "rstp": {
            "enabled_ports": _mask_to_ports(raw["rstp.b"]["ena"], n),
        },
        "snmp": {
            "community": _hex_decode(raw["snmp.b"]["com"]),
            "contact": _hex_decode(raw["snmp.b"].get("ci", "")),
            "enabled": bool(raw["snmp.b"]["en"]),
            "location": _hex_decode(raw["snmp.b"].get("loc", "")),
        },
        "system": system,
        "vlans": vlans,
    }


# ── Encode: JSON config -> raw .swb sections ───────────────────────


def _encode(config):
    ports = config["ports"]
    n = len(ports)
    system = config["system"]

    # link.b — key order matters for format compatibility
    link = {
        "en": _bool_mask(ports, n, "enabled"),
        "blkp": _bool_mask(ports, n, "blocked"),
        "an": _bool_mask(ports, n, "auto_negotiate"),
        "dpxc": _bool_mask(ports, n, "duplex"),
        "fctc": _bool_mask(ports, n, "flow_control_tx"),
        "fctr": _bool_mask(ports, n, "flow_control_rx"),
        "spdc": [p["speed"] for p in ports],
        "cm": [p["cable_mode"] for p in ports],
        "qtyp": [p["qos_type"] for p in ports],
        "nm": [_hex_encode(p["name"]) for p in ports],
        "sfpr": [int(p["sfp"]) for p in ports],
    }

    # fwd.b
    fwd = {}
    for i in range(n):
        fwd[f"fp{i + 1}"] = _ports_to_mask(ports[i]["forward_to"])
    fwd["lck"] = _bool_mask(ports, n, "mac_lock")
    fwd["lckf"] = _bool_mask(ports, n, "mac_lock_filter")
    fwd["imr"] = _bool_mask(ports, n, "input_mirror")
    fwd["omr"] = _bool_mask(ports, n, "output_mirror")
    fwd["mrto"] = config["mirror"]["target_port"]
    fwd["vlan"] = [p["vlan_mode"] for p in ports]
    fwd["vlni"] = [p["vlan_receive"] for p in ports]
    fwd["dvid"] = [p["default_vid"] for p in ports]
    fwd["fvid"] = config.get("filter_vid", 0)
    fwd["srt"] = [p["storm_rate"] for p in ports]
    fwd["suni"] = _bool_mask(ports, n, "source_unknown")
    fwd["fmc"] = _bool_mask(ports, n, "forward_multicast")
    fwd["ir"] = [p["ingress_rate"] for p in ports]

    # lacp.b
    lacp = {
        "mode": [p["lacp_mode"] for p in ports],
        "sgrp": [p["lacp_group"] for p in ports],
    }

    # vlan.b — preserve field order
    vlans = []
    for v in config["vlans"]:
        vlans.append({
            "nm": _hex_encode(v["name"]),
            "mbr": _ports_to_mask(v["members"]),
            "vid": v["id"],
            "piso": int(v["port_isolation"]),
            "lrn": int(v["learning"]),
            "mrr": int(v["mirror"]),
            "igmp": int(v["igmp"]),
        })

    # sys.b — preserve field order
    sys_ = {
        "id": _hex_encode(system["identity"]),
        "wdt": int(system["watchdog"]),
        "dsc": int(system["discovery"]),
        "pdsc": _ports_to_mask(system["port_discovery"]),
        "ivl": int(system["ivl"]),
        "alla": int(system["allow_from_all_addresses"]),
        "allm": int(system["allow_from_all_mgmt"]),
        "avln": system["admin_vlan"],
        "allp": _ports_to_mask(system["all_ports"]),
        "mgmt": int(system["management"]),
        "prio": system["stp_priority"],
        "cost": system["stp_cost_mode"],
        "frmc": int(system["frame_size_check"]),
        "poe": int(system["poe"]),
        "igmp": int(system["igmp_snooping"]),
        "igmq": int(system["igmp_query"]),
        "igfl": int(system["igmp_flood"]),
        "igve": int(system["igmp_vlan_exclusive"]),
        "ip": _le_ip_encode(system["ip"]),
        "dtrp": _ports_to_mask(system["drop_tagged"]),
        "ainf": int(system["auto_info"]),
        "iptp": system["ip_type"],
    }

    # snmp.b
    snmp = {
        "en": int(config["snmp"]["enabled"]),
        "com": _hex_encode(config["snmp"]["community"]),
        "ci": _hex_encode(config["snmp"]["contact"]),
        "loc": _hex_encode(config["snmp"]["location"]),
    }

    return {
        "vlan.b": vlans,
        "lacp.b": lacp,
        ".pwd.b": {"pwd": _hex_encode(config["password"])},
        "snmp.b": snmp,
        "rstp.b": {"ena": _ports_to_mask(config["rstp"]["enabled_ports"])},
        "link.b": link,
        "fwd.b": fwd,
        "sys.b": sys_,
        "acl.b": config.get("acl", []),
        "host.b": config.get("hosts", []),
    }


# ── CLI ─────────────────────────────────────────────────────────────


def main():
    ap = argparse.ArgumentParser(
        description="Generate and parse MikroTik SwOS switch backup files."
    )
    sub = ap.add_subparsers(dest="command")
    sub.required = True
    sub.add_parser("generate", help="JSON stdin -> .swb stdout")
    sub.add_parser("parse", help=".swb stdin -> JSON stdout")

    args = ap.parse_args()

    if args.command == "parse":
        raw = _parse_swb(sys.stdin.read())
        config = _decode(raw)
        json.dump(config, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    elif args.command == "generate":
        config = json.load(sys.stdin)
        raw = _encode(config)
        sys.stdout.write(_serialize_swb(raw))


if __name__ == "__main__":
    main()
