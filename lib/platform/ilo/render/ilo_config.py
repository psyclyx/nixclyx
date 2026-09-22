#!/usr/bin/env python3
"""Declarative iLO configuration over Redfish, with a diff/apply flow.

Mirrors routeros-config: egregore emits a desired-state JSON document, this
renders/diffs it against what the BMC actually has, and pushes only the
delta. Nothing here reads egregore — it takes JSON on stdin, same as the
RouterOS generator, so it stays a platform back-end rather than a projection.

    ilo-config generate            < spec.json
    ilo-config diff  --current c.json < spec.json
    ilo-config apply [--dry-run] HOST < spec.json

Auth comes from ILO_USER / ILO_PASSWORD (or --password-file), so the caller
decides where credentials live and this never learns about sops.

Why sections carry an apply mode
--------------------------------
Redfish surfaces differ in when a write takes effect, and that difference is
load-bearing for planning a no-downtime change:

  live        takes effect immediately (accounts, SSH keys)
  host-reboot staged in a Settings resource, applied at next POST (BIOS)
  bmc-reset   needs an iLO restart (manager network)

`apply` reports the modes it touched so the operator knows what still has to
happen for the change to be real. A BIOS PATCH that returns 200 has changed
nothing yet.
"""
import base64
import json
import os
import ssl
import sys
import urllib.error
import urllib.request

# section key → (read path, write path, apply mode)
#
# iLO 4 keeps BIOS attributes flat on the resource (no Redfish-standard
# `Attributes` wrapper), and the pending values live on a separate Settings
# resource: you read current from BIOS/ and write desired to BIOS/Settings/.
# Reading Settings instead would report what is *staged*, not what is live,
# and the diff would go quiet while the box stayed unchanged.
SECTIONS = {
    "bios": {
        "read": "/redfish/v1/Systems/1/BIOS/",
        "write": "/redfish/v1/Systems/1/BIOS/Settings/",
        "mode": "host-reboot",
    },
}

APPLY_MODE_NOTE = {
    "live": "in effect now",
    "host-reboot": "staged — applies at next host POST",
    "bmc-reset": "needs an iLO reset",
}


def _auth_header():
    user = os.environ.get("ILO_USER")
    password = os.environ.get("ILO_PASSWORD")
    if not user or not password:
        sys.stderr.write("error: ILO_USER and ILO_PASSWORD must be set\n")
        raise SystemExit(2)
    raw = f"{user}:{password}".encode()
    return "Basic " + base64.b64encode(raw).decode()


def _ctx(insecure):
    if not insecure:
        return None
    c = ssl.create_default_context()
    c.check_hostname = False
    c.verify_mode = ssl.CERT_NONE
    return c


def _request(host, path, insecure, method="GET", body=None, etag=None):
    url = f"https://{host}{path}"
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", _auth_header())
    req.add_header("Accept", "application/json")
    if data is not None:
        req.add_header("Content-Type", "application/json")
    if etag:
        # iLO rejects an unconditional PATCH on some resources; If-Match also
        # makes the write fail loudly if the BMC changed under us mid-run.
        req.add_header("If-Match", etag)
    try:
        with urllib.request.urlopen(req, context=_ctx(insecure), timeout=30) as r:
            payload = r.read()
            return json.loads(payload) if payload else {}, r.headers.get("ETag")
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:400]
        sys.stderr.write(f"{method} {path} -> HTTP {e.code}\n{detail}\n")
        raise SystemExit(1)


def nic_boot_map(host, insecure):
    """adapter → {port: NicBootN}, from the BIOS attribute mappings.

    Deliberately not derived from EthernetInterfaces/N MAC addresses: iLO
    only populates those for ports it can see link on, and the embedded NIC
    reports nothing at all while the host sits in POST — which is exactly
    the state a machine is in when you need to fix its boot order. Mappings
    is static BIOS metadata, so it answers with the host wedged or powered
    off.

    Each PCI instance carrying NicBootN subinstances is one adapter; its
    `PreBootNetwork` association gives the adapter the name the operator
    already uses (EmbNic, FlexLom1, ...), and subinstance order is port
    order on that adapter.
    """
    doc, _ = _request(host, "/redfish/v1/Systems/1/BIOS/Mappings/", insecure)
    out = {}
    for inst in doc.get("BiosPciSettingsMappings", []):
        adapter = None
        for assoc in inst.get("Associations", []):
            if isinstance(assoc, dict) and "PreBootNetwork" in assoc:
                adapter = assoc["PreBootNetwork"]
        subs = inst.get("Subinstances", [])
        if adapter is None or not subs:
            continue
        ports = {}
        for sub in subs:
            names = [a for a in sub.get("Associations", [])
                     if isinstance(a, str) and a.startswith("NicBoot")]
            if names:
                ports[sub["Subinstance"]] = names[0]
        if ports:
            out[adapter] = ports
    return out


def expand_network_boot(spec, nicmap):
    """Turn declared PXE seats into concrete NicBoot* BIOS attributes.

    The spec names which (adapter, port) seats are allowed to network-boot;
    every other seat the firmware knows about is explicitly Disabled. Saying
    it exhaustively is the point — a NIC left enabled by omission is how a
    box ends up stalling forever on a PXE attempt nobody meant to allow.
    """
    want = spec.pop("network_boot", None)
    if want is None:
        return spec
    enabled = {(s["adapter"], s["port"]) for s in want.get("pxe", [])}
    unknown = [s for s in enabled if s[0] not in nicmap
               or s[1] not in nicmap[s[0]]]
    if unknown:
        raise SystemExit(f"error: no NicBoot seat for {sorted(unknown)}; "
                         f"firmware offers { {a: sorted(p) for a, p in nicmap.items()} }")
    attrs = {}
    for adapter, ports in nicmap.items():
        for port, nic_attr in ports.items():
            attrs[nic_attr] = ("NetworkBoot" if (adapter, port) in enabled
                               else "Disabled")
    spec.setdefault("bios", {}).update(attrs)
    return spec


def fetch_current(host, spec, insecure):
    """Read back only the attributes the spec actually mentions.

    Scoping the read to the spec keeps the diff honest: a BMC exposes
    hundreds of BIOS attributes and we are not their owner. Anything not
    named in the spec is left alone and never reported as drift.
    """
    current = {}
    for section, want in spec.items():
        if section not in SECTIONS:
            sys.stderr.write(f"warning: unknown section '{section}', skipping\n")
            continue
        live, _ = _request(host, SECTIONS[section]["read"], insecure)
        current[section] = {k: live.get(k) for k in want}
    return current


def diff(current, spec):
    """spec ∧ current → {section: {attr: (from, to)}} for attrs that differ."""
    ops = {}
    for section, want in spec.items():
        if section not in SECTIONS:
            continue
        have = current.get(section, {})
        changed = {k: (have.get(k), v) for k, v in want.items() if have.get(k) != v}
        if changed:
            ops[section] = changed
    return ops


def format_plan(ops, host=None):
    if not ops:
        return "Already in sync; nothing to apply.\n"
    out = []
    if host:
        out.append(f"# Plan for {host}")
    for section, changed in ops.items():
        mode = SECTIONS[section]["mode"]
        out.append(f"\n[{section}]  ({mode}: {APPLY_MODE_NOTE[mode]})")
        for attr, (frm, to) in sorted(changed.items()):
            out.append(f"  {attr}: {frm!r} -> {to!r}")
    return "\n".join(out) + "\n"


def cmd_generate(args):
    spec = json.load(sys.stdin)
    json.dump(spec, sys.stdout, indent=2, sort_keys=True)
    sys.stdout.write("\n")
    return 0


def cmd_diff(args):
    spec = json.load(sys.stdin)
    with open(args.current) as f:
        current = json.load(f)
    sys.stdout.write(format_plan(diff(current, spec)))
    return 0


def cmd_apply(args):
    spec = json.load(sys.stdin)
    if args.password_file:
        with open(args.password_file) as f:
            os.environ["ILO_PASSWORD"] = f.read().rstrip("\n")
    if args.user:
        os.environ["ILO_USER"] = args.user

    sys.stderr.write(f"Pulling current state from {args.host}...\n")
    spec = expand_network_boot(spec, nic_boot_map(args.host, args.insecure))
    current = fetch_current(args.host, spec, args.insecure)
    ops = diff(current, spec)

    sys.stdout.write(format_plan(ops, args.host))
    if not ops or args.dry_run:
        return 0

    modes = set()
    for section, changed in ops.items():
        sec = SECTIONS[section]
        body = {attr: to for attr, (_, to) in changed.items()}
        _, etag = _request(args.host, sec["write"], args.insecure)
        sys.stderr.write(f"PATCH {sec['write']} ({len(body)} attribute(s))...\n")
        _request(args.host, sec["write"], args.insecure,
                 method="PATCH", body=body, etag=etag)
        modes.add(sec["mode"])

    sys.stderr.write("\nApplied.\n")
    for m in sorted(modes):
        if m != "live":
            sys.stderr.write(f"  NOT YET IN EFFECT — {m}: {APPLY_MODE_NOTE[m]}\n")
    return 0


def main():
    import argparse
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--insecure", action="store_true", default=True,
                    help="Skip TLS verification (iLO ships a self-signed cert).")
    sub = ap.add_subparsers(dest="command")
    sub.required = True

    sub.add_parser("generate", help="Echo the desired-state spec (review aid).")

    sp = sub.add_parser("diff", help="Spec + captured current-state -> plan.")
    sp.add_argument("--current", required=True)

    sp = sub.add_parser("apply", help="Pull current, diff, PATCH the delta.")
    sp.add_argument("host", help="iLO hostname or address.")
    sp.add_argument("--dry-run", action="store_true")
    sp.add_argument("--user")
    sp.add_argument("--password-file")

    args = ap.parse_args()
    return {"generate": cmd_generate, "diff": cmd_diff,
            "apply": cmd_apply}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
