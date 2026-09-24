# nixclyx

Public version of @psyclyx's homelab nix configuration.

# Cheat sheets

## ssh-keygen

### Generate keys

#### Host key

```bash
ssh-keygen -t ed25519 -N "" -C "" -f /etc/ssh/id_ed25519_host_key
ssh-keygen -t ed25519 -N "" -C "" -f /etc/secrets/initrd/id_ed25519_host_key
```

#### User key

```bash
ssh-keygen -t ed25519 -N "" -C "user@host" -f ~/.ssh/id_ed25519
```

### Extract public key from private key

```bash
ssh-keygen -y -f /etc/ssh/id_ed25519
```

### Sign keys (SSH CA)

#### Create a CA

```bash
ssh-keygen -t ed25519 -N "" -C "my-ca" -f ca_key
```

#### Sign a host key

```bash
ssh-keygen -s ca_key -I "hostname" -h -n "hostname,hostname.example.com" host_key.pub
# produces host_key-cert.pub
```

- `-h` marks it as a host certificate
- `-n` sets valid principals (hostnames)
- `-V +52w` to set validity (optional, default unlimited)

#### Sign a user key

```bash
ssh-keygen -s ca_key -I "user@example.com" -n "root,deploy" user_key.pub
# produces user_key-cert.pub
```

- `-n` sets valid principals (usernames the cert can log in as)
- `-V +90d` to set validity

### Inspect a certificate

```bash
ssh-keygen -L -f key-cert.pub
```

## Wireguard

### Generate keys

#### Private key

```bash
wg genkey > private.key
chmod 600 private.key
```

#### Public key (from private)

```bash
wg pubkey < private.key > public.key
```

#### Preshared key (optional, per-peer)

```bash
wg genpsk > preshared.key
```

# The egregore model

The fleet is a graph of entities that projections read. An entity has
one id, refs (named edges, inverted into `refsIn`), tags (free-text
grouping), and aspects. There is no type field: the type of an entity
is the name of its present kind (`e.host != null`).

Aspects share one namespace of three categories: **kind** (the nature
of a thing: `host`, `network`, `service`, `site`, `route`, …), **facet**
(a concern kinds share: `dns`, `boot`, `exposures`), **capability** (a
value read by name: `address`). An aspect is written as data or
computed (`derive` hooks) — same structure, read the same way. The
egregore core is `lib/egregore` (shippable, no fleet knowledge);
`modules/egregore` is this fleet's schema; host configuration is one
node's mechanism; `lib/platform/<p>` is one platform's config system.

Rules of placement:

- **Derivation** — use a relation for a fact when the relation is the
  fact. Read the ref; do not copy the data.
- **Declaration** — write a fact as data when it is a choice or an
  observation.
- **Coincidence** — do not derive a fact from a relation that only
  equals the fact.
- **Locality** — keep each fact in one place.
- **Dispatch** — the name of an exposure gives identity; its role
  selects the projection.
- **Placement** — ask of each field: nature or configuration? fact or
  mechanism? edge or node? universal, or fleet/vendor-specific? Does
  it depend on a frame?

Network vocabulary: a **network** is a segment (VLAN, subnet, gateway);
a **site** is a place (domain + networks); a **scope** is a place a
listener is reachable from (maps to an address key); a **DNS view** is
a record set a resolver answers from, joined to scopes by a ref.

An **exposure** is a named listener reservation on a node (`role`,
`port`, `scopes`, `identity`). It states where a listener is when it is
active — not when it is active (that is host configuration) and not
whom a client logs in as (that is client configuration). An
**offering** is what the fleet supplies — domain, ingress, check, HA —
and runs on an exposure, which it refs (`{ target; exposure; }`).
