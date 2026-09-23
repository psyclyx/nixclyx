# Egregore end state

The target architecture for the egregore, and the plan to get there. This
is the companion to `PLACEMENT.md`: `PLACEMENT.md` says *which layer* a noun
belongs to; this says *what the machinery is* and *how the graph is built*.

Decisions are recorded where they belong, marked **●**, and collected in §8.

## 0. Principles

1. **Layers.** `lib/egregore` is shippable: zero knowledge of psyclyx.
   `modules/egregore` is fleet schema — but still *schema*, not
   implementation. Mechanisms for one box go to host config.
2. **Derive = set.** A consumer reading `entity.foo` cannot tell whether you
   wrote `foo` or a module computed it. We do not encode provenance in the
   structure — no separate "derived" namespace.
3. **The elevation rule.** A thing is a top-level *aspect* iff **more than
   one kind of entity carries it**, or **something depends on it through the
   registry**. Otherwise it is a *field* of the aspect that owns it. (This is
   what keeps `sshPort` / `initrdVlans` from being promoted.)
4. **The layer test**, applied to every field: nature or configuration? fact
   or mechanism? edge or node? universal or fleet/vendor? frame-bearing?

## 1. The model

- **Entity** — a node in the graph, keyed by a unique **id**. Refs are flat
  by id; the id is the subject.
- **Aspect** — something an entity *has*: `entities.iyr.node`,
  `entities.iyr.routing`, `entities.mdf-agg01.routeros`. Peer, open (any
  module adds one), multi (any subset), present iff non-null. Authored and
  derived aspects share one namespace.
- **Capability** — an aspect whose *schema is its contract*: `address`,
  `fqdn`, `ssh`, `l2`, `routes`. Consumers ask for capabilities, never for
  kinds. `with "ssh"` is "everything sshable".
- **Kind** — an aspect that defines an entity's primary nature
  (`node` + `platform`; `network`; `service`; `site`; `route`). Kinds are
  ordinary aspects; the only special thing is that some are exclusive.
- **Universal** — `refs`, `tags` (and the implicit `name`), declared by core.
- **View** — a lazily-computed derived configuration (a capability query
  materialized). Optional; see §2.6.

`type`, `config.types`, `mkType`, `mkTypeExtend`, `extends`, the
`egregoreType` interceptor, and the separate `attrs`/`provides` bags all go
away.

## 2. The mechanism composition

Each module-system primitive, and exactly what it is doing for us.

### 2.1 `entities` is a **lazy** attrset — `attrsWith { lazy = true; }`

```nix
options.egregore.entities = mkOption {
  type = types.attrsWith {
    lazy = true;
    placeholder = "id";             # docs read `entities.<id>.<aspect>`
    elemType = types.submoduleWith { … };   # §2.2
  };
  default = { };
};
```

`attrsOf`'s `merge` runs a strictness pass (`filterAttrs (… optionalValue …)`,
`types.nix:1021`) that **forces every element on any membership check** —
`entities ? x` evaluates every entity. `attrsWith { lazy = true; }` drops that
pass: on access the value is `optionalValue.value or emptyValue.value or
mergedValue` (`types.nix:1030`).

**Honest scope (I tested both):** strict `attrsOf` *works today* for egregore,
including acyclic cross-entity value references — this is a precaution, not a
correctness fix. `lazy = true` is preferred because (a) membership/enumeration
stops forcing the world, (b) it tolerates a sibling value-reference that strict
forces-and-recurses (the `lib/tests/modules/lazy-attrsWith.nix` case), and
(c) it matches how nixpkgs treats comparable bags (`_module.args`,
`configData`, `images`).

- Cost: **conditional definitions of elements stop working** — `mkIf false`
  leaves the key present (throwing on access). Fine for entity data, which is
  always present; `mkIf` *inside* an entity (on aspects) still works.
- This laziness also makes the self-referential `egregore` module arg (§2.2)
  comfortably legal.

### 2.2 Entity options come from **aspect modules** via `submoduleWith`

A submodule is already a nested `evalModules`: its `merge` runs
`base.extendModules { modules = allModules defs; }` and returns
`configuration.config` (`types.nix:1477`), and `emptyValue = base.config`
(so an entity has every declared aspect, defaulted). So the entity "type" is
just `submoduleWith` with the aspect modules:

```nix
elemType = types.submoduleWith {
  modules = aspects;                       # every aspect module
  specialArgs = { egregore = config.egregore; };   # the whole graph, lazily
};
```

- **Aspects are plain modules** — `{ options.routing = …; config.… = …; }`.
  No `mkType`, no spec field, no interceptor. An aspect that adds a field to
  another aspect just declares more options under it; the module system
  merges (`optionTreeToOption` / `mergeOptionDecls`, `modules.nix:850`). That
  is the whole of "extension", so `extends` is unnecessary.
- **`specialArgs` carries the top graph in.** Inside `entities.<id>`,
  `config` is the *entity*; a `specialArgs.egregore` (= the top config) is how
  an aspect derives from neighbours (`egregore.entities.<other>…`). This
  replaces today's `topConfig` function-closure. It self-references
  `config.egregore.entities`, which is only a thunk — safe because §2.1 is lazy.
- **Aspect set = the module list** passed to `egregore.eval`. It is the
  registry: enumerable for queries, docs, and "does X provide Y?" checks.

### 2.3 Genuine sums are `attrTag`

`platform` ("one of nixos/routeros/swos/sodola/ilo") is a tagged union, and
`attrTag` (`types.nix:1074`) is exactly that — one tag set, open (modules
merge tags via its `binOp`), with the tag's own submodule schema.

We do **not** build a general "slot" mechanism. The only real exclusivity in
the fleet is platform; everything else composes. If it turns out to need
enforcing beyond `attrTag`, it is one assertion.

### 2.4 Constraints are aspect-declared and checked generically

An aspect may carry metadata — `requires = [ "node" ]` (a capability the
entity must already have), `exclusive = true` — and core runs one pass over
present aspects. Open: a new aspect declares its own; no central enum, no
pairwise conflict lists.

`requires` is also what makes the expression-problem seam *loud*: assigning
`routing` to an entity whose platform provides nothing to route fails a named
check instead of silently doing nothing.

### 2.5 `deferredModule` + `extendModules` — modules as data, instantiated lazily

`types.deferredModule`'s merge returns `{ imports = [ … ]; }` (`types.nix:1313`),
so an option's value *is a module*. `extendModules`/`moduleType`
(`modules.nix:379`, and the `moduleType` arg at `modules.nix:249`) instantiate
the current config plus more modules, lazily. The idiom is
`nixos/modules/image/images.nix`:

```nix
config.image.modules = imageModules;                    # modules as data
imageConfigs = mapAttrs (n: m: extendModules { modules = [ m ]; }) config.image.modules;
config.system.build.images = mapAttrs (n: c: … c.config …) imageConfigs;
```

Used here for two things:

1. **Consumer extension.** An out-of-tree or host-side module contributes
   aspects/entities by putting `deferredModule`s in a config option; the view
   folds them in with `extendModules`. No `imports`-from-`config`, no cycle.
2. **Views (§2.6).**

### 2.6 Views

A **view** is a lazily-extended configuration: a capability query or a
**frame** materialized with `extendModules`/`moduleType`. It is forced only
when read, and it can declare *new* derived options without polluting the
base. The base graph holds frame-independent facts; a view applies a frame.

**● Decision.** Expose `extendModules` (and the eval's `type`) and nothing
more — no `view` DSL. A projection that needs to add derived options is
written as a view module; one that only reads the base is a plain query. The
primitive is already the right abstraction, and `images.nix` shows the shape
at fleet scale.

### 2.7 Query vocabulary

**● Decision (naming).** Components are the *authored* config and take a noun
or gerund: `node`, `platform`, `routing`, `dns`, `vpn`, `trust`,
`monitoring`, `boot`. Capabilities are the *queryable outcome* and take the
word you ask for: `address`, `fqdn`, `ssh`, `l2`, `routes`, `resolver`,
`power`, `console`, `monitor`. The paired names never share a bare noun
(`routing`↔`routes`, `dns`↔`resolver`, `monitoring`↔`monitor`) — that is the
whole point of the rule.

```nix
withAspect = a: entities: filterAttrs (_: e: e.${a} or null != null) entities;
hasAspect  = a: e: e.${a} or null != null;
withCapability = withAspect;    # same mechanism; only the naming differs
ofComponent / tagged / refsOf / referencedBy   # as today
```

### 2.8 Verified

Minimal standalone evals confirmed, before building anything:

- an `attrsWith { lazy = true; placeholder = "id"; }` of `submoduleWith
  { modules = aspects; specialArgs.egregore = <top config>; }` — two separate
  aspect modules contributed distinct options to the same entity (`greeting`,
  `label`) and merged, i.e. **extension needs no `extends`**;
- a derived aspect read a *neighbour* through the `egregore` arg
  (`audience = "seen-by-2"`) — cross-entity derivation works;
- a membership check (`entities ? a`) did not force the graph;
- `attrTag` gave a working `platform` sum (default `nixos`, overridden to
  `routeros`).

Caveat found and folded back into §2.1: the same eval also passes with
`lazy = false`, so laziness is a precaution (perf + sibling-reference
tolerance), not a correctness fix.

## 3. Core (concrete)

```nix
# lib/egregore/core.nix
{ config, lib, aspects ? [ ], ... }:
{ options.egregore.entities = mkOption {
    type = types.attrsWith {
      lazy = true; placeholder = "id";
      elemType = types.submoduleWith {
        modules = aspects;
        specialArgs = { egregore = config.egregore; };
      };
    };
    default = { };
  };
  config.assertions = requiresChecks ++ exclusivityChecks;
}
```

```nix
# aspects/routing.nix — a plain module into the entity submodule
{ config, lib, egregore, ... }:
{ options.routing = mkOption {
    type = types.nullOr (types.submodule { options = { static = …; }; });
    default = null;
  };
  options.routes = mkOption { … };          # the capability contract
  config.routes = lib.mkIf (config.routing != null) { … };
}
```

## 4. Fleet schema

- **Components (authored).** `node` (placement + attachment: site,
  addresses, interfaces, mac), `platform` (`attrTag`), `routing`, `dns`,
  `vpn`, `trust`, `monitoring`, `boot`, plus the standalone nouns.
- **Capabilities (derived, contract'd).** `address`, `fqdn`, `ssh`, `l2`,
  `routes`, `resolver`, `power`, `console`, `monitor`, `service`, `vip`,
  `tpm`. Each is declared once and derived by whichever components can
  produce it.
- A platform tag (e.g. `platform.routeros`) is where vendor schema lives.

Naming follows §2.7: authored components are nouns (`routing`), queried
capabilities are the question (`routes`).

### 4.1 ssh — three things, not one

ssh is the case that proves "one capability" wrong: the same word carries
facts that are consumed in different ways. Keep three things distinct.

1. **Offering.** A node's sshd is a `service` — an offering with a `port` and
   an `audiences` set. Because it is intrinsic to being a node it is carried
   as an aspect whose *schema is the service-offering schema*
   (`entities.iyr.ssh = { port = 17891; audiences = [ "vpn" ]; }`), and it
   appears in the service registry like any other service. The initrd sshd
   (unlock, port 8022) is a **second offering**, not this one.
2. **Endpoint.** Where to connect, *relative to a frame*: `{ host; port; }`,
   with `host` read from the node's `addresses.<net>` / `fqdns.<net>` for the
   consumer's frame. Deploy takes a canonical frame (public → site → vpn);
   the home ssh config takes the consumer's. Reachability is derived, never a
   stored string.
3. **Identity.** Host keys and certs, the SSH CA role that signs them
   (`openbao-ssh-cert-role`), principals, `known_hosts`. A **trust** concern,
   consumed by OpenBao, known_hosts generation, and NFS/Kerberos.

**`user` is offering policy, not reachability** — it belongs to (1), not (2).
That separation is the point: deploy, the home ssh config, initrd unlock, and
the CA each read the fact they need, and none of them overfits the others.

## 5. Noun plan

Every current noun, its disposition, and the principle that puts it there.
"lib" = `lib/egregore`; "fleet" = `modules/egregore`; "host" = host config.

| noun / field | layer | disposition |
|---|---|---|
| `site` | lib | place; `domain`, `location` |
| `network` | lib/fleet | segment; core `vlan`/`ipv4`/`ipv6`/`prefixLen`/gateway refs/`mtu` in lib; `zone` (firewall convention) fleet; address **plan** (`ulaPrefix`/`ipv6PdSubnetId`) fleet fact; **mechanism** (`underlay`/`dhcpRelay`) host config |
| `node` (was `host` intrinsic) | lib | site, addresses, interfaces, mac |
| `platform` (was `host`/`routeros`/`swos`/`sodola`/`ilo`) | fleet | `attrTag`; vendor schema per tag |
| `service` | lib | offering + presentation; unchanged |
| `route` | lib | path |
| `ssh` | fleet | *three things* (§4.1): an **offering** (service-shaped aspect: `port` + `audiences`; initrd unlock is a second offering), an **endpoint** (frame-relative `{host; port;}`, derived), and an **identity** (trust: host cert, CA role, principals) |
| `deployAddress` | lib (derived) | a chosen frame; stays derived |
| `initrdVlans` | **host** | boot mechanism, not a fleet fact |
| `routing`/`gateway` | fleet | facet; attachable to any node (host *or* switch) |
| `dns` (`dnsAuthority`, `publicNames`, `publicAcme`) | fleet | facet; exposes the `resolver` capability. The authority zone list is a fleet fact (see `network`/`zone`); the mechanism is host config |
| `vpn` (`wireguard`) | fleet | facet |
| `trust` (`openbao`, `kerberos`, `tpm`, `clevis`) | fleet + host | declarations fleet; mechanisms host |
| `monitoring` (`exporters`) | fleet | facet |
| `boot` (`mode`, `pxeInterfaces`, `firmwareNics`) | fleet + host | intent fleet; recipe host |
| `hardware` (`tpm`) | fleet | small fact facet |
| `firewall` | host + fleet | plumbing host; `globals.policy` fleet |
| `environment`, `ha-group`, `prefix-delegation`, `unmanaged` | fleet | standalone nouns |
| `lun`, `nfs-export` | fleet | storage **edges** |
| `zfs-pool`, `zfs-dataset`, `tpm-key` | **host** | box mechanisms (PLACEMENT §5) |
| `kv-secret`, `openbao-*` | fleet | trust declarations; **review each** |
| `clevis-binding` | fleet + host | binding fleet; seal host |

## 6. Consumers

Everything that reads the graph reads **capabilities**, not kinds:
`withAspect "ssh"` in `ssh-hosts.nix` and `deployments.nix`; `withAspect
"monitor"` for Prometheus; `withAspect "l2"` for switch projections. No
`e.type == …`, no null-checks except at the capability boundary.

## 7. Migration phases

Each phase is gated on the *current* eval: entity attrs, iyr + lab toplevel
derivations, and the four platform artifacts unchanged.

0. **This document.** Decisions are settled (§8); this is the reference.
1. **Capabilities, additive.** Add the three ssh pieces (§4.1) plus
   `address`/`fqdn` as derived aspects; keep `type` for now. Move
   `sshPort`/`deployUser` into the ssh offering; derive the endpoint; point
   `ssh-hosts.nix` + `deployments.nix` at `withAspect "ssh"`. Proves the
   interface layer with no schema churn.
2. **Laziness.** `entities` → `attrsWith { lazy = true; placeholder = "id"; }`.
   Verify no recursion, outputs unchanged.
3. **Promote facets** out of `host.*` (`routing`/`dns`/`vpn`/`trust`/
   `monitoring`/`boot`) with `requires`.
4. **Collapse the type layer.** `platform` as `attrTag`; aspects become plain
   modules under `submoduleWith`; delete `type`/`config.types`/`mkType`/
   `mkTypeExtend`/`extends`/interceptor. Byte-identical.
5. **Re-place nouns** (§5): `initrdVlans` → host config; `network` mechanism
   fields → host config; `zfs-*`/`tpm-key` → host config.
6. **Sweep projections** onto capabilities.
7. **Views** (§2.6) where a projection needs to add derived options.

## 8. Decisions

Settled; recorded for quick reference.

1. **Views.** Expose `extendModules`/`type` only; no `view` DSL (§2.6).
2. **ssh.** Three things — offering (service-shaped aspect), endpoint
   (frame-relative, derived), identity (trust) (§4.1).
3. **`platform`.** `attrTag` on a generic `node`; vendor schema lives in the
   tag's submodule (§2.3).
4. **Naming.** Authored components are nouns, queried capabilities are the
   question; paired names never share a bare noun (§2.7).
5. **`network` addressing.** The address *plan* (`ulaPrefix`,
   `ipv6PdSubnetId`) is a fleet fact — routers, reverse DNS, and the
   `prefix-delegation` entity all read it; the *mechanism* (`underlay`,
   `dhcpRelay`) is host config.
6. **Consumer contribution.** Read-only for now — no config-side seam until a
   real consumer needs one; `extendModules` is there if one does.

## 9. Progress

Landed, each gated (entity attrs, iyr + lab-1 system derivations, the four
platform artifacts — all byte-identical):

- ✅ **§2.1 lazy entity set** — `attrsWith { lazy = true; placeholder = "id"; }`
  in core and both type functions.
- ✅ **aspect core (enables §1)** — a type's bag is `nullOr (submodule …)`
  (default null), type modules gate on `config.<type> != null`, and core
  **derives** `config.type`. All 110 authored `type = "…"` discriminators
  removed from the data; *presence is the sole source*. This is the
  linchpin: a non-type capability aspect is now just another such option.
- ✅ **§4.1 ssh capability** — `attrs.ssh = { port; user; }` on hosts and
  routeros (the *offering*); `withAspect`/`hasAspect` helpers; ssh-hosts,
  deployments, and openssh repointed at it. `withAspect "ssh"` yields all
  13 sshable entities uniformly (hosts and switches).

Not yet done:

- ⏳ **§7.3 promote facets** out of `host.*` (`routing`/`dns`/`vpn`/`trust`/
  `monitoring`/`boot`). Needs `mkAspect` (a non-type aspect) + an interceptor
  + splitting `host-fleet.nix` into facet modules, then ~15 consumer reads.
- ⏳ **§7.6 consumer sweep**: ~180 `attrs.*` reads are still path-based. The
  namespace collapse (`entity.attrs.foo` → `entity.foo`) is the big one.
- ⏳ **§7.5 noun re-placement** (`initrdVlans`, `network` mechanisms,
  `zfs-*`/`tpm-key`).
- ⏳ **§7.7 views**.
