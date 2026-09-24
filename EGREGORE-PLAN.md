# Egregore migration plan

This document is the path from the current code to the model in
`EGREGORE.md`. `EGREGORE.md` is the target (a reference specification);
this is how to get there, phase by phase, each gated.

Read `EGREGORE.md` §9 first — it is the realization the phases build
toward.

## 1. Current state

### Landed (each gated byte-identical; nixclyx commits)

| commit | change |
|---|---|
| `7c5224c1` | `entities` is a lazy set: `attrsWith { lazy = true; placeholder = "id"; }` |
| `33190829` | the type is derived from the present kind aspect; authored `type = "…"` removed from all data (privclyx: `5f42004`) |
| `08053f68` | `ssh` is a capability key (`attrs.ssh = { port; user; }`); `withAspect`/`hasAspect`; ssh-hosts, deployments, openssh repointed |
| `aa98a6f9` | host facets are top-level aspects (`mkAspect` + `egregoreAspect`); `host-fleet.nix` → `modules/egregore/aspects/host-facets.nix` (privclyx: `a9f1d7a`) |
| `86d63426` | `EGREGORE.md` = the model specification |
| `2ce93ee3` | `exposures` aspect (the model's four fields) with the derived form in `attrs.exposures`; `exposuresOf`/`withRole`; `host.deployUser` and `attrs.ssh.user` removed — the account is client policy (`sshHosts.user`) |
| `e5b3cffb` | `host.sshPort` → declared `ssh` exposures on every host and switch; `initrd-ssh` (8022, scopes) replaces `gateway.initrdVlans` and the `gateway` facet; ssh-hosts/deployments/openssh read the exposures (privclyx: `9cf4c4b`) |
| `02a0593f` | `exporters.<name>` → exporter exposures (role `exporter`, port, scopes); computed exporters derive, data declares/overrides; monitoring reads the exposure scopes |
| `8fea7c68` | scope/DNS-view split: `audiences` → `scopes` (reachability, address key only); `dnsViews.<n>.records` (authoritative vs localzone) with the `scopes.<n>.view` ref; ingress dispatches on the view, record values from the scope's address key (privclyx: `3b33ff5`) |
| `2fc18e09` | offerings: `service.backend.host` is the exposure ref (`{ target; exposure; }`), `backend.network`/`backend.port` gone — the exposure owns port and scopes; `resolvedPort`/`resolvedAddress` derive from the target exposure (privclyx: `c1954da`) |
| `72430570` | attrs collapse: every derived key is a declared top-level option on its kind/facet (`derive` hook + `deriveOptions`; no freeformType); `attrs.refs` → `edges`, `attrs.name` → `name`; the derived `site`/`network` keys deleted (kind collisions); exposures one home, `exposuresOf` reads `e.exposures` (privclyx: `5cbbafb`) |
| `a0d89166` | drop `type`: the type of an entity is the name of the kind that is present — no field stores it; `ofType` → `withKind` (`e.${kind} != null`), `mkType`/`mkTypeExtend` write no `type`, the `types` registry stays as registration; the core assertion checks kind presence (exactly one registered kind present); consumers and the CLI dispatch on the present kind (privclyx: `61f44e5`) |
| `2ebb00ce` | realization (Phase 8): the entity is `submoduleWith { modules = aspects; specialArgs = { egregore = topConfig; }; }` — the top graph reaches every aspect module as the `egregore` module argument; `mkType`/`mkTypeExtend`/`mkAspect` lose the `topConfig` parameter, hooks are `name: entity: egregore: …`, the interceptors inject no closure |
| `d74df978` | `verbs` gone (cleanup): the core `verbs` option, the `verbs` hook parameter of `mkType`/`mkTypeExtend`, `withVerb`, and the CLI's strip lists — nothing read them |
| `2182e116` | earlier progress notes |

### Code shape

- **Entry:** `egregore.nix` → `configs/egregore/default.nix` → `lib/spec` compile of
  `modules/egregore` `typeSpecs ++ aspectSpecs ++ extensionSpecs ++ dataSpecs`.
- **Core:** `lib/egregore/core.nix` declares the entity submodule:
  `type` (derived, `default = ""`), `tags`, `refs`, `relations`, `refsIn`,
  `attrs` (an open bag, still), `verbs` (unused), `assertions`.
- **Type functions:** `lib/egregore/lib.nix` — `mkType` (kind: `options.<name> =
  nullOr (submodule …)`, sets `config.type`), `mkTypeExtend` (adds options under a
  type name, no default, no `type` write), `mkAspect` (top-level entity options, no
  `type` write), `ofType`, `withAspect`/`hasAspect`, the `egregoreType` and
  `egregoreAspect` interceptors.
- **Generic types:** `lib/egregore/modules/types/{host,network,service,site,route}.nix`.
- **Fleet types:** `modules/egregore/types/*.nix` (20) and
  `modules/egregore/aspects/host-facets.nix`.
- **Extensions:** `modules/egregore/extensions/{audiences,globals}.nix`.
- **Consumers:** `modules/nixos/derived/*.nix`, `modules/{routeros,swos,sodola,ilo}/projection.nix`,
  `modules/home/programs/ssh-hosts.nix`, `deployments.nix`,
  `modules/nixos/network/gateway.nix` + `interfaces.nix`, `packages/egregore.nix` (CLI).
- **Data:** `configs/egregore/*.nix` (nixclyx), `infra/privclyx/configs/egregore/*.nix`.

## 2. Gaps

| Model (`EGREGORE.md`) | Current | Gap |
|---|---|---|
| Aspects in one namespace | an `attrs` bag; 41 files read `.attrs.` | Declare the derived keys per kind; sweep the consumers. |
| No field holds the type | a derived `type`; 42 files read `.type`/`ofType` | Dispatch on kind presence and exposure role. |
| Exposure (§6) | none; ssh is `attrs.ssh`; exporters are `exporters.*`; the initrd is `gateway.initrdVlans` | Add the `exposures` aspect; migrate the listeners. |
| Offering (§5) | `service` embeds `backend = { host; network; port }` and `audiences` | Offering = entity backed by an exposure ref. |
| Scope and DNS view (§7) | one `audiences` concept doing reachability, address key, and DNS view | Split; join with a ref. |
| Realization (§9) | `mkType` with a `topConfig` closure and a `type` gate | `submoduleWith` with an `egregore` argument. |

## 3. Phases

Each phase is a separate commit in `infra/nixclyx` (and `infra/privclyx` when
its data moves). Gate every phase with §5.

### Phase 1 — add the exposure aspect (additive)

Introduce the `exposures` aspect with the model's four fields
(`role`; `port`; `scopes`; `identity`). In this phase, **derive** it from the
current data so the model is observable before anything moves:

- `ssh` exposure from `host.sshPort` / `host.deployUser` / `routeros.sshUser`;
- exporter exposures from `exporters.<name>`;
- an `initrd-ssh` exposure from `gateway.initrdVlans`.

Add `withRole`. Nothing consumes `exposures` yet.

Files: a new `modules/egregore/aspects/exposures.nix` (a `mkAspect`), plus
derivations in `lib/egregore/modules/types/host.nix`,
`modules/egregore/types/routeros.nix`, `modules/egregore/aspects/host-facets.nix`.

Gate: unchanged (pure addition to `attrs`; nothing reads it yet).

### Phase 2 — ssh and initrd-ssh become exposures

- Move `host.sshPort` (and the routeros ssh port) into `ssh` exposures
  (declared). `host.deployUser` has already left egregore and does not
  return: the login account is session policy, not fleet data — it lives
  in home-manager's `sshHosts.user` (beside `identityFile`) and
  populates the ssh config, and deployment acts against those ssh
  targets with no account of its own. `routeros.sshUser` stays, but as
  device config: the admin account the routeros projection installs keys
  on (named as User in generated entries), not a session or deployment
  fact.
- Add the `initrd-ssh` exposure (port 8022, scopes — declared).
- Point `modules/home/programs/ssh-hosts.nix` and `deployments.nix` at the
  `role == "ssh"` exposures.
- Point the initrd projection (`modules/nixos/derived/gateway.nix`) at the
  `initrd-ssh` exposure's scopes. Delete `gateway.initrdVlans` and the `gateway`
  facet.

Gate: ssh-hosts output, deployments targets, iyr derivation unchanged.

### Phase 3 — exporters become exposures

Replace `exporters.<name>.networks` with the exposure `scopes`. Point
`modules/nixos/derived/monitoring.nix` at the exposures.

Gate: Prometheus target output unchanged.

### Phase 4 — split scope from DNS view

- Rename `audiences` → `scopes` (reachability only): `configs/egregore/audiences.nix`
  and `modules/egregore/extensions/audiences.nix`, plus `service.audiences` and
  every reader.
- Add the DNS view as its own concept. Join a view to a scope with a ref.
- Remove the DNS-record and certificate derivation from the scope
  (`modules/nixos/derived/ingress.nix`, `public-names.nix`, `zones.nix`,
  `dns-authority.nix`).

Gate: DNS records, certificates, and ingress output unchanged.

### Phase 5 — offerings

Make `service` an offering: an entity backed by an exposure ref. The exposure
owns `port` and `scopes`; the offering owns domain, ingress, check, HA. Remove
`backend.network` and `backend.port` from the offering (`service.backend.host`
becomes the exposure ref).

Files: `lib/egregore/modules/types/service.nix`,
`modules/nixos/derived/{ingress,tang,ha,ha-services}.nix`,
`configs/egregore/services.nix`, private service configs.

Gate: ingress, DNS, monitoring output unchanged.

### Phase 6 — collapse `attrs` into aspects

- Declare each derived key as a closed option on its kind (and facet). The keys
  are produced today by 26 modules (`rg -l '^\s+attrs =|config\.attrs\.'
  lib/egregore/modules/types modules/egregore/types modules/egregore/aspects`).
- Sweep the 41 files: `e.attrs.x` → `e.x`. Rename `attrs.refs` (the rich form)
  to a non-colliding name (`edges`), because `refs` is a declared option.
- Point `withAspect`/`hasAspect` at the top-level aspects.
- Watch the collision: `host`'s `site` key versus the `site` kind. Rename the
  key or the option.

Gate: the **rendered configuration**, not the store path — this changes the
serialized graph (see the `psyclyx-link` note in §6).

### Phase 7 — drop `type`

Consumers dispatch on kind presence (`e.host != null`) and exposure role.
`ofType` → `withKind`. Remove the `type` field from `core.nix`.

Gate: system derivations unchanged.

### Phase 8 — realization (polish)

Use `submoduleWith { modules = aspects; specialArgs = { egregore = topConfig; }; }`
instead of `types.submodule` + the `topConfig` closure. Pass the top graph as the
`egregore` argument to the aspects; drop the closure from the interceptor.

Gate: unchanged.

### Cleanup

Remove `verbs` from `core.nix` and `lib.nix` (the model has none; nothing reads it).

## 4. Order and dependencies

- Phases 1–3 (the exposure) are the keystone and prove the model. They do not
  depend on 6–7.
- Phases 4–5 (scopes/views, offerings) depend on the exposure.
- Phases 6–7 are the large mechanical sweeps. Do them after 1–3, so the new
  facts are aspects already. They do not depend on 4–5.
- Phase 8 is last.

## 5. Gate

Run at each phase. Compare against the pre-change state with a stash.

### Entity attrs (the model's observable output)

```sh
cat > /tmp/egdump.nix <<'EOF'
let
  lib = import <nixpkgs/lib>;
  spec = import /home/psyc/projects/monorepo/infra/nixclyx/egregore.nix;
  eg = import spec.lib { inherit lib; };
  f = eg.eval { modules = [ spec.root ]; };
in builtins.mapAttrs (n: e: e.attrs) f.entities
EOF
nix-instantiate --eval --strict --read-write-mode --json /tmp/egdump.nix > /tmp/eg_new.json
```

### System derivations

```sh
for h in iyr lab-1 semuta sigil tleilax glyph; do
  nix-instantiate --eval --read-write-mode -E \
    "let m = import /home/psyc/projects/monorepo; in m.nixosConfigurations.$h.config.system.build.toplevel.drvPath"
done
```

### Platform artifacts

```sh
for p in routerosSystems.idf-dist01.json swosSystems.mdf-acc01.json \
         sodolaSystems.mdf-brk01.script iloSystems.lab-1-ilo.json; do
  sys="${p%.*}"; art="${p##*.}"
  nix-build --no-out-link -E \
    "let m = import /home/psyc/projects/monorepo; in m.nixclyx.${sys}.config.system.build.${art}"
done
```

### Old vs new

`infra/nixclyx` and `infra/privclyx` are separate git repositories. To capture
the old side, stash **both** (a change in one usually needs the other), eval,
then pop.

```sh
cd infra/nixclyx && git stash -u -q; cd ../privclyx && git stash -u -q
# … eval the old side …
cd ../privclyx && git stash pop -q; cd ../nixclyx && git stash pop -q
```

## 6. Working notes and gotchas

- **The aspect set is one option.** `options.entities` is declared by core,
  `mkType`, `mkTypeExtend`, and `mkAspect`. They must all agree on `lazy` and
  `placeholder`, or the module system rejects the combined declaration
  (`attrsWith`'s `binOp` returns `null` when `lazy` differs). This is why the
  lazy change touched all of them.
- **`nullOr (submodule …)` is the presence marker.** An unset aspect is `null`.
  A kind's `config.type` is written when its aspect is present.
- **Extension has no helper.** A second module adds options under an aspect by
  declaring `options.<name> = mkOption { type = nullOr (submodule …); }` (no
  `default`), which the module system merges with the base. There is no
  `mkTypeExtend`/`extends` in the target.
- **Not every module reads `attrs` with a dot path.** `kerberos.nix` read
  `attrByPath ["host" "kerberos" "fqdnNetwork"]` — a string path that a
  `.host.` sed misses. Search for `attrByPath [ … "host" … ]` and for
  `getAttr "host"` when moving facets.
- **Session accounts are not graph facts.** `deployUser` is gone from
  `host`; the login account is client policy (`sshHosts.user`, beside
  `identityFile`) and deployment is dumb ssh against the generated
  entries. The one account the graph keeps is `routeros.sshUser` — the
  device's admin account, which the projection installs keys on.
- **`psyclyx-link` embeds the whole graph.** `infra/privclyx/packages/psyclyx-link`
  does `writeText (toJSON egregorData)`. Any graph-shape change gives it a new
  store path even when its output is identical. Gate on the **rendered output**,
  not the store path. It is the reason `tleilax`'s derivation changes when the
  graph shape changes: `tleilax` serves `psyclyx-link` through nginx.
- **`freeformType` was rejected** for the namespace collapse: it exposes derived
  keys at the top level but loses typo-catching (a misspelled aspect becomes a
  freeform attribute).
- **Private data lives in `infra/privclyx`** (`configs/egregore/*`,
  `modules/nixos/*`, `packages/psyclyx-link`). Commit there separately.
- **`backend.local.port` intentionally stays.** A local offering is an
  aspect of the node that fronts it (model §5) — there is no node to
  ref, so no exposure ref is written. Open point: if the model later
  wants local exposures (a listener reservation for localhost backends
  too), `backend.local` folds into an exposure on the fronting node.

## 7. Pre-existing breakage (do not chase)

- `lab-4`: `attribute 'nodes' missing` (microvm host). Fails at the session's
  base commit too.
- `cherub` (privclyx): `psyclyx.nixos.network.derived` does not exist (stale,
  referenced nowhere else).

Neither is caused by this work. Gate on the hosts that evaluate: iyr, lab-1..3,
semuta, sigil, tleilax, glyph, omen.

## 8. Definition of done

- [x] `EGREGORE.md` holds the model; the code matches it. (Realization
  landed with Phase 8 — `submoduleWith` + the `egregore` argument.)
- [x] No `attrs` bag; derived facts are aspects. No `type` field. Exposures exist;
  offerings ref them. Scope and DNS view are distinct. `verbs` gone.
- [x] Every consumer reads aspects and exposures, not `attrs` and `type`.
- [x] The gate is green at each commit. (Every row above was gated
  old-vs-new; Phase 8 gate is "everything unchanged", the cleanup's
  delta is confined to the CLI sweep and the serialized graph's empty
  `verbs` keys.)
