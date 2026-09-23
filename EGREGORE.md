# Egregore Model Specification

## 1. Purpose

This document specifies the egregore data model. The model describes the
fleet as a graph of entities that projections read. This document defines
the vocabulary and the rules. It does not define projections.

The migration from the current code to this model is in
`EGREGORE-PLAN.md`.

## 2. Terminology

The terms in this table have one meaning each in this document.

| Term | Meaning |
|---|---|
| entity | A node of the graph. |
| id | The unique name of an entity. |
| ref | A directed edge from one entity to another. |
| refsIn | The inverse index of all refs. |
| tag | A text label on an entity. |
| aspect | A named part of an entity. |
| kind | The aspect that gives the nature of an entity. |
| facet | An aspect for a concern that two or more kinds share. |
| capability | An aspect that a consumer reads by name. |
| offering | A thing that the fleet supplies. |
| exposure | A listener on a node. |
| network | A segment. |
| site | A place. |
| scope | A place from which a listener is reachable. |
| DNS view | A record set that a resolver answers from. |

## 3. Entity

An entity has one id, zero or more refs, zero or more tags, and zero or
more aspects.

**id** — unique. Two entities never have the same id.

**refs** — each ref names one target entity and one edge name. A ref is
declared on the entity that the edge serves. The edge `gateway`, for
example, is declared by a network, and the target is the router. The edge
name is free text; the model fixes no set of edge names.

**refsIn** — computed, not declared. On an entity, `refsIn.NAME` lists
every entity that refs this entity with the edge name `NAME`. A host reads
`refsIn.gateway` and finds the networks that it routes.

**tags** — free text. A tag has no model meaning. Projections select groups
of entities with tags.

## 4. Aspect

An aspect is a named part of an entity. An entity has any number of
aspects. Any module contributes an aspect. An aspect is present when its
value is not null.

The aspects of an entity use one namespace. The namespace holds three
categories.

| Category | Function | Examples |
|---|---|---|
| kind | Gives the nature of an entity. | `host`, `network`, `service` |
| facet | Holds a concern that two or more kinds share. | `routing`, `dns`, `vpn` |
| capability | Holds a value that a consumer reads by name. | `address`, `ssh` |

The type of an entity is the name of the kind that is present. No field
stores the type.

An aspect is either written as data or computed from relations. Both forms
have the same structure. A consumer reads both forms in the same way.

**Extension.** A module adds a field to an aspect when the module declares
an option with the same aspect name. The module system merges the options.

**Elevation.** A fact becomes an aspect when two or more kinds carry the
fact, or when a consumer reads the fact by name. A fact that fails this
test is a field of the aspect that owns it.

## 5. Offering

An offering is a thing that the fleet supplies. The identity of an offering
includes its domain, its ingress, its check, and its HA group.

An offering has one of two shapes.

| Shape | Definition |
|---|---|
| fleet offering | An entity. Other entities ref it. |
| local offering | An aspect of a node. |

An offering runs on an exposure. The offering refs the exposure. Section 6
defines the exposure.

## 6. Exposure

An exposure is a listener on a node. An exposure is an aspect of the node.

An exposure has a name. The name is the key of the aspect. The name gives
identity to the exposure; an offering refs an exposure by name.

| Field | Type | Meaning |
|---|---|---|
| role | text | The kind of listener. A projection reads this field. The egregore core does not read this field. |
| port | integer | The port of the listener. |
| scopes | list of scope names | The places that reach the listener. |
| identity | ref | The key or the certificate of the listener. |

An exposure is a reservation. It states where a listener is when the
listener is active. It does not state when the listener is active. The
active time of a listener is host configuration.

## 7. Network

Four concepts relate to the network. The concepts are distinct. A ref joins
two concepts.

| Concept | Definition | Examples |
|---|---|---|
| network | A segment. A network has a VLAN, a subnet, and a gateway. | `main`, `storage` |
| site | A place. A site has a domain and a group of networks. | `apt`, `co-location` |
| scope | A place from which a listener is reachable. A scope is not a segment. A scope maps to an address key. | `public`, `vpn`, `apt` |
| DNS view | A record set that a resolver answers from. Two DNS views give different records for one name. | the public view, the internal view |

## 8. Rules

**8.1 Derivation.** Use a relation for a fact when the relation is the fact.
The DNS servers of a network are the servers that the network refs. Read
the ref. Do not copy the data.

**8.2 Declaration.** Write a fact as data when the fact is a choice or an
observation. The scopes of the management ssh of a node are a choice. Write
the scopes.

**8.3 Coincidence.** Do not derive a fact from a relation that only equals
the fact.

**8.4 Locality.** Keep each fact in one place. A reader finds the network
posture of a node in one place.

**8.5 Dispatch.** The name of an exposure gives identity. The role of an
exposure selects the projection. A projection dispatches on the role, not
on the name.

**8.6 Placement.** Apply this test to each field.

1. Does the field give the nature of a thing, or the configuration of a
   thing?
2. Is the field a fact, or a mechanism?
3. Is the field an edge, or a node?
4. Is the field universal, or specific to the fleet or to a vendor?
5. Does the field depend on a frame?

**8.7 Layers.** The layers hold the model as follows.

| Layer | Contents |
|---|---|
| `lib/egregore` | The vocabulary (`site`, `network`, `host`, `service`, `route`) and this model. Shippable. No knowledge of the fleet. |
| `modules/egregore` | The schema of the fleet: its kinds, facets, offerings, and exposures. |
| host configuration | The mechanism of one node. |
| `lib/platform/<p>` | The configuration system of one platform. No knowledge of egregore. |

## 9. Realization

The model uses the NixOS module system.

| Model part | Module-system form |
|---|---|
| entity set | `attrsWith { lazy = true; placeholder = "id"; }` |
| entity | `submoduleWith { modules = aspects; specialArgs = { egregore = topConfig; }; }` |
| aspect | A module over entity options. |
| extension | A second module with the same aspect name. |
| sum | `attrTag` |
| view | `extendModules` |
| query | `withAspect` |

The argument `egregore` gives the top graph to the aspects. An aspect reads
the top graph and finds a neighbour.

A derived key is a declared option. Derived keys are closed and checked.
