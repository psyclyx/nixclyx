# nixclyx

The shared NixOS framework. Tier-2 of the three-tier egregore architecture
described in the parent repo's `CLAUDE.md`.

## Layering invariants

- **`modules/egregore/types/*.nix`** — entity types. Describe intrinsic
  properties only. No fleet entity names as defaults. No deployment
  shape (listen addresses, cert strategies, DNS-registration methods).
  No reads from globals to compute defaults.
- **`modules/egregore/extensions/`, `modules/egregore/generators/`** —
  framework-side helpers. Fleet-agnostic.
- **`modules/nixos/<area>/*.nix`** (excluding `topology/`) — generic
  NixOS sugar. Pure options + module config that produces stock NixOS
  output (`systemd.*`, `services.*`, etc.). Must NOT read
  `config.psyclyx.egregore`.
- **`modules/nixos/topology/*.nix`** — projections. Read
  `config.psyclyx.egregore` and set options on generic modules under
  `psyclyx.nixos.<area>.*`. Must NOT write `systemd.*` / `services.*`
  directly; if a projection needs something a generic module doesn't
  expose, extend the generic module first.
- **`configs/egregore/*.nix`** — fleet data. Declare the minimum
  intrinsic facts; derive the rest.
- **`hosts/nixos/<host>/`** — host configs. Enable projections, set
  host-specific intrinsic options. Should not contain raw
  `${eg.entities.X.…}` reach-throughs unless `X` is the host's own
  name resolved from `config.networking.hostName` /
  `config.psyclyx.nixos.host`. Literal IPs/MACs that already live in
  egregore data must be derived, not duplicated.

## Address-mode contract

Tier-3 host entities declare *where* they live (interfaces + networks)
and *how their address is set* via `host.addresses.<net>`:

| egregore declaration | runtime shape |
|---|---|
| `addresses.<net>.dhcp = true` | networkd unit emits `DHCP=yes`. Kea on the network's DHCP server holds a per-MAC reservation; the host gets its declared `ipv4` from that reservation. **Default for non-gateway hosts.** |
| `addresses.<net>.{ipv4,ipv6}` set, `dhcp = false` | Static address written into the unit. Used by hosts that *are* the network's gateway (via `topology/gateway.nix`), not via the per-host projection. |
| `addresses.<net>.ipv4 = null`, `dhcp = false` | Configuration error; assertion fires. Either declare a static IP, mark it DHCP, or stop declaring the address. |

Two operational requirements follow from this:

1. Every network with hosts that declare DHCP-mode addresses needs a
   Kea pool on that VLAN's DHCP server. For switch-routed VLANs where
   the DHCP server isn't the gateway (e.g., apt-site lab/storage VLANs
   routed by `mdf-agg01`), the DHCP server still needs an L2 anchor
   on that VLAN — see the `enp1s0.210` / `enp1s0.200` pattern in
   `hosts/nixos/iyr/`.
2. The projection in `modules/nixos/topology/network.nix` is the
   single enforcement point for this contract. Per-host configs do
   not write address lines into networkd directly.
