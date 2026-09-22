#!/usr/bin/env python3
"""sodola-config: Generate and parse Sodola switch backup files.

Supports the SL902-SWTGW218AS binary backup format (2665 bytes).

Usage:
    sodola-config generate [--hex] < config.json
    sodola-config parse [--hex] < backup.bin
"""

import argparse
import json
import struct
import sys

# ── Constants ────────────────────────────────────────────────────────

FILE_SIZE = 2665
MAGIC = b"#y#y"
NUM_PORTS = 9
MAX_VLAN_SLOTS = 32
STORM_CATS = ["broadcast", "multicast", "unknown_unicast", "known_unicast"]
STORM_DISABLED = 0xFFFFFF00
RATE_UNLIMITED = 0x00FFFFF0
ALL_PORTS_MASK = (1 << NUM_PORTS) - 1  # 0x1ff

DEFAULT_FLAGS = "0000020101200801"
DEFAULT_PW_HASH = (
    "3c6d3e3d383939696a3069616e3331377a2d7c2a7d2d287e7420707274227377"
)

# Diagonal port matrix — constant STP structure (91 bytes at 0x8b4).
_DIAG = bytearray(91)
for _p in range(9):
    _DIAG[_p * 10 + _p] = 0x08
    if _p + 2 < 10:
        _DIAG[_p * 10 + _p + 2] = 0x04
_DIAG[90] = 0x04
DIAGONAL_MATRIX = bytes(_DIAG)

# Fixed sequences in the tail section.
TAIL_93D = bytes([0x00, 0x02, 0x00, 0x00, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x00])
TAIL_947 = bytes([0x00, 0x01])
PORT_SEQ = bytes(
    [
        0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00,
        0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x04, 0x00,
        0x00, 0x00, 0x05, 0x00, 0x00, 0x00, 0x06, 0x00,
        0x00, 0x00,
    ]
)


# ── Helpers ──────────────────────────────────────────────────────────


def _ip_pack(ip_str):
    """Dotted-quad IPv4 string -> 4 bytes big-endian."""
    return bytes(int(o) for o in ip_str.split("."))


def _ip_unpack(b):
    """4 big-endian bytes -> dotted-quad string."""
    return ".".join(str(x) for x in b)


def _str_pack(s, size):
    """ASCII string -> null-padded bytes of exactly *size*."""
    return s.encode("ascii")[:size].ljust(size, b"\x00")


def _str_unpack(b):
    """Null-padded bytes -> stripped ASCII string."""
    end = b.find(b"\x00")
    return (b[:end] if end >= 0 else b).decode("ascii", errors="replace")


def _u16(buf, off):
    return struct.unpack_from(">H", buf, off)[0]


def _u32(buf, off):
    return struct.unpack_from(">I", buf, off)[0]


def _mask_to_ports(val, n=NUM_PORTS):
    """Bitmask integer -> sorted list of 1-based port numbers."""
    return sorted(i + 1 for i in range(n) if val & (1 << i))


def _ports_to_mask(ports):
    """List of 1-based port numbers -> bitmask integer."""
    return sum(1 << (p - 1) for p in ports)


def _vlan_name(vlans, vid):
    """Look up a VLAN name by ID."""
    for v in vlans:
        if v["id"] == vid:
            return v.get("name", "")
    return ""


# ── Generate ─────────────────────────────────────────────────────────


def _encode_port9(ports_cfg, vlan_id, is_member):
    """Compute port-9 membership byte (bit 0 = tagged, bit 1 = native).

    A trunk port that is a member of a VLAN is tagged for that VLAN unless the
    VLAN is the port's native VLAN, in which case it is native (untagged).
    """
    if not is_member:
        return 0
    p = ports_cfg[8]
    if p.get("native_vlan", 1) == vlan_id:
        return 2  # native/untagged
    if p.get("mode") == "trunk":
        return 1  # tagged
    return 0


def generate(config):
    """Serialize a config dict to a 2665-byte Sodola backup."""
    buf = bytearray(FILE_SIZE)

    net = config["network"]
    auth = config.get("auth", {})
    ports = config["ports"]
    vlans = config.get("vlans", [])
    mirror = config.get("mirror", {})
    stp = config.get("stp", {})

    if len(ports) != NUM_PORTS:
        raise ValueError(f"expected {NUM_PORTS} ports, got {len(ports)}")

    # ── Header (0x00 – 0x5f, 96 bytes) ──────────────────────────────
    buf[0x00:0x04] = MAGIC
    buf[0x05:0x09] = _ip_pack(net["ip"])
    buf[0x09:0x0D] = _ip_pack(net["netmask"])
    buf[0x0D:0x11] = _ip_pack(net["gateway"])
    buf[0x17:0x27] = _str_pack(auth.get("username", "admin"), 16)
    buf[0x2C:0x4C] = bytes.fromhex(auth.get("password_hash", DEFAULT_PW_HASH))

    # ── Switch flags (0x60 – 0x6d) ──────────────────────────────────
    buf[0x60:0x68] = bytes.fromhex(config.get("flags", DEFAULT_FLAGS))
    buf[0x68] = NUM_PORTS
    buf[0x69] = NUM_PORTS

    # ── Storm control (0x6e, 4 categories × 9 ports × 4B = 144B) ───
    for ci, cat in enumerate(STORM_CATS):
        for pi in range(NUM_PORTS):
            off = 0x6E + (ci * NUM_PORTS + pi) * 4
            val = ports[pi].get("storm_control", {}).get(cat)
            struct.pack_into(">I", buf, off, STORM_DISABLED if val is None else val)

    # ── Port mirroring (0x130, 4B) ──────────────────────────────────
    buf[0x130] = mirror.get("source", 0)
    buf[0x131] = mirror.get("destination", 0)
    buf[0x132] = mirror.get("direction", 0)

    # ── Speed (0x134 – 0x1af) ───────────────────────────────────────
    buf[0x134:0x138] = b"\x06\x01\x80\x80"
    for blk in range(10):
        base = 0x138 + blk * 12
        for pi in range(NUM_PORTS):
            buf[base + pi] = (
                0x01 if ports[pi].get("speed", "auto") == "auto" else 0x00
            )

    # ── Rate limits (0x1c8 ingress, 0x1f8 egress) ──────────────────
    for i in range(NUM_PORTS):
        v = ports[i].get("ingress_rate")
        struct.pack_into(">I", buf, 0x1C8 + i * 4, RATE_UNLIMITED if v is None else v)
    for i in range(NUM_PORTS):
        v = ports[i].get("egress_rate")
        struct.pack_into(">I", buf, 0x1F8 + i * 4, RATE_UNLIMITED if v is None else v)

    # ── Port isolation (0x24e, 9 × 4B) ─────────────────────────────
    for i in range(NUM_PORTS):
        iso = ports[i].get("isolation_mask")
        mask = ALL_PORTS_MASK if iso is None else _ports_to_mask(iso)
        struct.pack_into(">I", buf, 0x24E + i * 4, mask << 16)

    # ── Unknown per-port constant (0x27c, 9 × 4B) ──────────────────
    for i in range(NUM_PORTS):
        struct.pack_into(">I", buf, 0x27C + i * 4, 0x00001000)

    # ── Management VLAN hint (0x4be) ────────────────────────────────
    struct.pack_into(">H", buf, 0x4BE, config.get("mgmt_vlan_hint", 1))

    # ── Native VLAN per port (0x4cc, 9 × 2B) ───────────────────────
    for i in range(NUM_PORTS):
        struct.pack_into(">H", buf, 0x4CC + i * 2, ports[i].get("native_vlan", 1))

    # ── Port VLAN type (0x4e4, 9B) ─────────────────────────────────
    for i in range(NUM_PORTS):
        buf[0x4E4 + i] = 0x02 if ports[i].get("mode") == "access" else 0x00

    # ── VLAN ID table + sort index ─────────────────────────────────
    user_vids = sorted(set(v["id"] for v in vlans) - {1})
    vid_table = (
        [1, 1] + user_vids + [0xFFFF] * (MAX_VLAN_SLOTS - 2 - len(user_vids))
    )
    n_used = 2 + len(user_vids)
    sort_idx = list(range(n_used)) + [0xFFFF] * (MAX_VLAN_SLOTS - n_used)

    for i in range(MAX_VLAN_SLOTS):
        struct.pack_into(">H", buf, 0x4F0 + i * 2, sort_idx[i])
        struct.pack_into(">H", buf, 0x530 + i * 2, vid_table[i])

    # ── VLAN data (0x570 – 0x891) ──────────────────────────────────
    buf[0x570:0x572] = b"\xff\xff"

    # Slot 1 VID + name (0x574, 18B)
    struct.pack_into(">H", buf, 0x574, vid_table[1])
    buf[0x576:0x586] = _str_pack(_vlan_name(vlans, vid_table[1]), 16)

    # VLAN membership lookup
    vmem = {v["id"]: v.get("members", []) for v in vlans}

    # 30 interleaved blocks (0x586, 30 × 26B)
    for pos in range(30):
        base = 0x586 + pos * 26
        mem_slot = pos + 1
        vid_slot = pos + 2

        # Membership for VLAN at mem_slot
        mv = vid_table[mem_slot] if mem_slot < MAX_VLAN_SLOTS else 0xFFFF
        if mv != 0xFFFF:
            members = vmem.get(mv, [])
            b1 = _encode_port9(ports, mv, 9 in members)
            b2 = sum(1 << (p - 1) for p in members if 1 <= p <= 8)
            buf[base : base + 4] = bytes([0x00, b1, b2, 0x00])
            if mv == 1:
                buf[base + 4 : base + 8] = b"\x00\x00\x00\x01"
            else:
                buf[base + 4 : base + 8] = bytes([0x00, b1, b2, 0x01])

        # VID + name for vid_slot
        vv = vid_table[vid_slot] if vid_slot < MAX_VLAN_SLOTS else 0xFFFF
        if vv != 0xFFFF:
            struct.pack_into(">H", buf, base + 8, vv)
            buf[base + 10 : base + 26] = _str_pack(
                _vlan_name(vlans, vv), 16
            )

    # ── Diagonal matrix (0x8b4, 91B) ───────────────────────────────
    buf[0x8B4 : 0x8B4 + 91] = DIAGONAL_MATRIX

    # ── Tail (0x90f – 0xa68) ───────────────────────────────────────
    buf[0x939:0x93D] = b"\x76\xad\xf1\x00"
    buf[0x93D:0x947] = TAIL_93D
    buf[0x947:0x949] = TAIL_947

    # STP global
    struct.pack_into(">H", buf, 0x94B, stp.get("bridge_priority", 32768))
    buf[0x94D] = stp.get("max_age", 20)
    buf[0x94E] = stp.get("hello_time", 2)
    buf[0x94F] = stp.get("forward_delay", 15)

    # STP per-port (0x950, 9 × 10B)
    for i in range(NUM_PORTS):
        pb = 0x950 + i * 10
        struct.pack_into(">I", buf, pb, ports[i].get("stp_path_cost", 0))
        buf[pb + 7] = ports[i].get("stp_priority", 128)

    # IGMP
    buf[0x9C9] = 1 if config.get("igmp_enabled", False) else 0

    # QoS per-port queue (0x9cf, 9B)
    for i in range(NUM_PORTS):
        buf[0x9CF + i] = ports[i].get("qos_queue", 1)

    # QoS weights (0x9dc, 4 × 4B) — stored as weight << 8 in the binary.
    weights = config.get("qos_weights", [3, 2, 4, 1])
    for i in range(4):
        struct.pack_into(">I", buf, 0x9DC + i * 4, weights[i] << 8)

    # Port numbering sequence + model
    buf[0xA34 : 0xA34 + 26] = PORT_SEQ
    buf[0xA4E] = 0x07
    buf[0xA4F : 0xA5F] = _str_pack(config.get("model", "SL902-SWTGW218AS"), 16)

    assert len(buf) == FILE_SIZE
    return bytes(buf)


# ── Parse ────────────────────────────────────────────────────────────


def parse(data):
    """Deserialize a 2665-byte Sodola backup to a config dict."""
    if len(data) != FILE_SIZE:
        raise ValueError(f"expected {FILE_SIZE} bytes, got {len(data)}")
    if data[0:4] != MAGIC:
        raise ValueError(f"bad magic: {data[0:4]!r}")

    config = {}

    config["network"] = {
        "gateway": _ip_unpack(data[0x0D:0x11]),
        "ip": _ip_unpack(data[0x05:0x09]),
        "netmask": _ip_unpack(data[0x09:0x0D]),
    }

    config["auth"] = {
        "password_hash": data[0x2C:0x4C].hex(),
        "username": _str_unpack(data[0x17:0x27]),
    }

    config["flags"] = data[0x60:0x68].hex()

    config["igmp_enabled"] = bool(data[0x9C9])

    config["mgmt_vlan_hint"] = _u16(data, 0x4BE)

    config["mirror"] = {
        "destination": data[0x131],
        "direction": data[0x132],
        "source": data[0x130],
    }

    config["model"] = _str_unpack(data[0xA4F:0xA5F])

    # Ports
    ports = []
    for i in range(NUM_PORTS):
        port = {}

        # Storm control
        sc = {}
        for ci, cat in enumerate(STORM_CATS):
            val = _u32(data, 0x6E + (ci * NUM_PORTS + i) * 4)
            sc[cat] = None if val == STORM_DISABLED else val
        port["storm_control"] = sc

        # Speed — check if all 10 speed blocks have 0x01 for this port
        speed_vals = [data[0x138 + blk * 12 + i] for blk in range(10)]
        port["speed"] = "auto" if all(v == 0x01 for v in speed_vals) else "manual"

        # Rates
        ing = _u32(data, 0x1C8 + i * 4)
        port["ingress_rate"] = None if ing == RATE_UNLIMITED else ing
        eg = _u32(data, 0x1F8 + i * 4)
        port["egress_rate"] = None if eg == RATE_UNLIMITED else eg

        # Isolation
        iso_raw = _u32(data, 0x24E + i * 4) >> 16
        port["isolation_mask"] = _mask_to_ports(iso_raw)

        # VLAN mode and native VLAN
        port["native_vlan"] = _u16(data, 0x4CC + i * 2)
        mode_byte = data[0x4E4 + i]
        port["mode"] = "access" if mode_byte == 0x02 else "trunk"

        # STP per-port
        pb = 0x950 + i * 10
        port["stp_path_cost"] = _u32(data, pb)
        port["stp_priority"] = data[pb + 7]

        # QoS
        port["qos_queue"] = data[0x9CF + i]

        ports.append(port)
    config["ports"] = ports

    config["qos_weights"] = [_u32(data, 0x9DC + i * 4) >> 8 for i in range(4)]

    config["stp"] = {
        "bridge_priority": _u16(data, 0x94B),
        "forward_delay": data[0x94F],
        "hello_time": data[0x94E],
        "max_age": data[0x94D],
    }

    # VLANs
    vid_table = [_u16(data, 0x530 + i * 2) for i in range(MAX_VLAN_SLOTS)]

    vlans = []
    seen = set()
    for slot in range(MAX_VLAN_SLOTS):
        vid = vid_table[slot]
        if vid == 0xFFFF or vid in seen:
            continue
        if slot == 0:
            continue  # slot 0 is a duplicate header; real data at slot 1
        seen.add(vid)

        # Membership from interleaved block (slot S -> block S-1)
        block_idx = slot - 1
        members = []
        if 0 <= block_idx < 30:
            mbase = 0x586 + block_idx * 26
            b1 = data[mbase + 1]
            b2 = data[mbase + 2]
            for bit in range(8):
                if b2 & (1 << bit):
                    members.append(bit + 1)
            if b1 & 0x03:
                members.append(9)
            members.sort()

        # Name — slot S name is in block (S-2) bytes 10-25, or 0x576 for slot 1
        name = ""
        if slot == 1:
            name = _str_unpack(data[0x576:0x586])
        elif slot >= 2:
            nb = slot - 2
            if 0 <= nb < 30:
                nbase = 0x586 + nb * 26
                name = _str_unpack(data[nbase + 10 : nbase + 26])

        vlans.append({"id": vid, "members": members, "name": name})

    vlans.sort(key=lambda v: v["id"])
    config["vlans"] = vlans

    return config


# ── CLI ──────────────────────────────────────────────────────────────


def main():
    ap = argparse.ArgumentParser(
        description="Generate and parse Sodola switch backup files."
    )
    sub = ap.add_subparsers(dest="command")
    sub.required = True

    gen_p = sub.add_parser("generate", help="JSON stdin -> binary backup stdout")
    gen_p.add_argument(
        "--hex", action="store_true", help="emit hex string instead of raw binary"
    )

    par_p = sub.add_parser("parse", help="binary backup stdin -> JSON stdout")
    par_p.add_argument(
        "--hex", action="store_true", help="read hex string instead of raw binary"
    )

    args = ap.parse_args()

    if args.command == "generate":
        config = json.load(sys.stdin)
        result = generate(config)
        if args.hex:
            sys.stdout.write(result.hex())
        else:
            sys.stdout.buffer.write(result)

    elif args.command == "parse":
        if args.hex:
            data = bytes.fromhex(sys.stdin.read().strip())
        else:
            data = sys.stdin.buffer.read()
        config = parse(data)
        json.dump(config, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")


if __name__ == "__main__":
    main()
