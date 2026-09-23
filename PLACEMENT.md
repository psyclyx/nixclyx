# Placement: what lives where, and why

This is the working map for the layering refactor. It records the rule,
the layers, and where every existing noun lands — so a move is a lookup,
not a debate. It is provisional while `lib/` is still physically inside
nixclyx.

## The layers

| layer | dir | owns | depends on |
|---|---|---|---|
| **egregore core** | `egregore/` | the graph: entities, refs, relations, attrs, assertions, queries | `lib` |
| **egregore modules** | `lib/egregore/modules/` | the minimal vocabulary of fleet concepts (the egregore module library, à la `nixos/modules`) | core |
| **platform library** | `lib/platform/<p>/` | a config module system for a platform we *implement* (routeros, swos, sodola, ilo) + render + build/actions | nothing egregore |
| **fleet egregore schema** | `modules/egregore/` | this fleet's nouns and extensions — the concepts psyclyx actually uses | egregore modules |
| **fleet platform config** | `modules/<p>/` | this fleet's egregore→platform mappings and platform opinions | platform, fleet schema |
| **host config** | `hosts/`, `modules/nixos/` | genuinely local config (storage layout, TPM, services a host runs) | platform, fleet config |
| **data** | `configs/egregore/`, host instances | values only | schema |
| **cli** | `lib/cli/` | the manifest interpreter | build outputs only |

The invariant: **`lib/` never imports `modules/` or `configs/`.** `lib/` has
zero knowledge of psyclyx.

## The rule

A field belongs in the generic egregore module library only if it is
**intrinsic** (removing it
would stop the noun describing the thing) **and uncontested** (no
reasonable fleet would define it differently). Choices, conventions, and
vendor/technology names are out.

Evictions go two ways:
- **fleet egregore schema** — if the fleet must know it (referenced across
  hosts, part of the topology/identity/trust graph);
- **host config** — if it is only how one box is set up.

**Cohesion exceptions** are allowed in `modules/` (fleet) but not in
`lib/` (shippable): an attr or two on an existing noun when splitting
would scatter one concept. They are marked `COHESION EXCEPTION`, additive
only (never a new noun or edge), never a layer inversion, and they
graduate the moment a second consumer needs them. See `service.kind`.

## Fact placement (the four axes)

When placing a fact: **subject** (is it a fleet node/edge or a host
implementation detail?), **scope** (place it at the finest granularity
that can vary — per family, interface, route, uplink), **kind** (given
data vs derived query; derived *edges* go through `refsIn`), **modality**
(capability, default, override, applicability are four facts, not one).
A field answering more than one of these is more than one field.

## A service is an offering plus a presentation

`service` split into what changes for different reasons:

- **intrinsic** — `protocol`, `backend` (ha | host | local), `audiences`
  (reach). What it offers, where it runs, who can reach it.
- **presentation** — `domain`/`environment`, `ingress`, `websockets`,
  `streaming`, `check`. How it is named and proxied, per context.
- **exception** — `kind`: a one-word label. Not a mechanism carrier.

An `audience` is a pure reachability scope. **A proxy is a service**
(`service.proxy`, naming the host it runs on) whose `audiences` are the
scopes it fronts; a service exposed in a scope is routed by the proxy
serving it, overridable per service. An audience no proxy serves is
reached directly at the service's backend. The projection's HAProxy
config, certs, and DNS are a projection over that data; a direct-reach
projection owns the rest.

This is what lets `tang` be a service (HTTP offering, host backend, no
FQDN, no ingress) instead of a vendor noun.

## The noun mapping

### → egregore modules (`lib/egregore/modules/`, shippable, ~6 nouns)

`site`, `network`, `host` (a.k.a. node), `service`, `route`.
Plus the extension mechanism and `audiences` (direct/ingressed).

The `host` noun is intrinsic only: `site`, `addresses`, `interfaces`,
`mac`, `roles`, `sshPort`, `deployAddress`, `deployUser`. Everything
fleet-shaped a host can be — `gateway`, `firewall`, `bgp`, `kerberos`,
`openbao`, `wireguard`, `hardware`, `boot`, `dnsAuthority`,
`public{Names,Acme}`, `exporters` — is a fleet convention, added to
the noun by name (`extends = "host"`).

### → fleet egregore schema (`modules/egregore/`) — the fleet must know it

`environment`, `ha-group` (a service backend), `prefix-delegation`,
`unmanaged`, `nfs-export`, `lun`, `clevis-binding`, the tang service (a
`service` of kind `tang`), `openbao-{pki,ssh-cert,cert}-role`,
`openbao-policy`, `openbao-seal-oracle`, `kv-secret`, the platform
node nouns `routeros` / `swos` / `sodola` / `ilo`, and the `host-fleet`
extension (the host blocks above).

### → host config (`modules/nixos/`, `hosts/`) — implementation of one box

`zfs-pool`, `zfs-dataset`, `tpm-key`, and the mechanisms behind every
service kind (tang keys, OpenBao roles, KDC database, NixOS units).

### → platform libraries (`lib/platform/<p>`) — generic config only

RouterOS menu schema + render + build/actions; same for SwOS, Sodola,
and iLO (Redfish). No egregore in any of them.

### Splits (files that fuse several of the above)

- `types/{routeros,swos,sodola,ilo}.nix` — node noun → `modules/egregore/`
  (an egregore module about a platform); menu schema + render →
  `lib/platform/<p>`; projection/mappings → `modules/<p>`.
- `types/service.nix` — already split in intent (offering/presentation);
  a shape move (grouping the presentation fields) is a later step.
- `types/host.nix` — ✅ re-sliced. The intrinsic noun (site,
  addresses, interfaces, mac, sshPort, deployUser, + derived
  deployAddress) is `lib/egregore/modules/types/host.nix`; the fleet
  blocks (wireguard, dnsAuthority, public{Names,Acme}, hardware, boot,
  openbao, gateway, kerberos, bgp, exporters) are the `host-fleet`
  extension (`modules/egregore/types/host-fleet.nix`), merged by
  `extends`. `roles` collapsed into the entity's `tags`; `deployAddress`
  derived; the gateway and firewall *mechanisms* (NICs, DHCP clients,
  QoS, per-host input policy, NAT) moved into host config. `boot` was
  already right: intent (mode / pxeInterfaces / firmwareNics) in
  egregore, recipe (initrd-ssh-netboot, pxe-server) in host config.
  Remaining fleet facts on the host — wireguard, dnsAuthority,
  public{Names,Acme}, hardware, openbao, kerberos, bgp, exporters —
  stay in egregore; they have no cleaner noun to sit on.

## Migration order

1. ✅ resolved inverse index (`refsIn`), drop hand-rolled gateway scans.
2. ✅ generalized `service` + `audience` (offering/presentation, direct).
3. ✅ direct reach via `service.reach`; tang is a `service` of kind
   `tang` (host config owns the mechanism).
4. Extract `lib/platform/<p>` from the platform node types (three-way
   split).
5. Demote `zfs-*`, `tpm-key` to host config; move the rest of the vendor
   nouns to `modules/egregore/`.
6. Physical moves: `egregore/` (core) + `egregore/modules/` +
   `lib/platform/` out of the fleet path; `modules/egregore/` becomes the
   fleet schema home.
7. CLI → manifest interpreter; `verbs` retired.8. ✅ split `host` into the intrinsic noun (`lib/egregore/modules/`)
   and the fleet `host-fleet` extension (`modules/egregore/`), via
   `extends`. Then `roles`→`tags`, derive `deployAddress`, and move the
   gateway + firewall mechanisms into host config. Byte-identical at
   each step (entity attrs, iyr gateway/cake-qos, iyr + lab firewalls,
   the four platform artifacts).

## See also

`EGREGORE.md` — the end-state machinery and the phased plan to reach it.
