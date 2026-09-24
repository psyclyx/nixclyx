# Shared port submodule and helpers for switch entity types.
#
# Port classification by field presence:
#   { vlan = N; }      → access (untagged)
#   { vlans = [...]; } → trunk (tagged)
#   { }                → unused (disabled)
#
# A port's `refs` are graph edges, same shape as an entity's: what is on
# the other end of the cable. Two conventional roles —
#
#   refs.host = "some-server"                          → an end station
#   refs.peer = { target = "a-switch"; port = "port9"; } → another switch
#
# — and the rich form names the far-side port or NIC, so a link can be
# checked rather than described in prose. `description` is what's left
# once the edge is modelled: free text for ports with nothing on the
# other end worth naming (a WAN handoff, an admin jack).
#
# Usage:
#   let portDef = import ./switch-port.nix { inherit lib egregorLib; };
#   in {
#     type = lib.types.attrsOf (lib.types.submodule portDef.module);
#     portDef.portType somePort   # → "access" | "trunk" | "unused"
#     portDef.portLabel somePort  # → human description
#     portDef.links entity.ports  # → normalized edge list
#   }
#
{ lib, egregorLib }:
rec {
  # Submodule for use in types.attrsOf (types.submodule portDef.module)
  module = {
    options = {
      vlan = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
      };
      vlans = lib.mkOption {
        type = lib.types.listOf lib.types.int;
        default = [];
      };
      lacpGroup = lib.mkOption {
        type = lib.types.int;
        default = 0;
        description = "LACP group ID (0 = none).";
      };
      refs = lib.mkOption {
        type = lib.types.attrsOf egregorLib.refType;
        default = {};
        description = ''
          What this port is cabled to. `host` for an end station, `peer`
          for another switch; the rich form names the far-side port/NIC.
          Targets are validated against the entity registry.
        '';
      };
      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = ''
          Free text for what the edge doesn't say — which of the target's
          roles this port serves, or what's on the far end when it isn't
          a modelled entity.
        '';
      };
    };
  };

  # A port that was never declared. Hardware ports absent from `ports`
  # get this, so every model port has a config to classify.
  empty = {
    vlan = null;
    vlans = [];
    lacpGroup = 0;
    refs = {};
    description = null;
  };

  portType = port:
    if port.vlan != null then "access"
    else if port.vlans != [] then "trunk"
    else "unused";

  portLabel = port: let
    host = if port.refs ? host then egregorLib.refNorm port.refs.host else null;
    peer = if port.refs ? peer then egregorLib.refNorm port.refs.peer else null;
    desc = port.description;
    # Which of the target's roles this port serves. Free text wins when
    # it's there; otherwise the edge already says it, so read it off the
    # attachment point rather than making someone restate it.
    qualifier = if desc != null then desc else (if host == null then null else host.nic);
  in
    if host != null && qualifier != null then "${host.target} ${qualifier}"
    else if host != null then host.target
    else if desc != null then desc
    else if peer != null then "trunk to ${peer.target}"
    else if port.vlan != null then "access VLAN ${toString port.vlan}"
    else if port.vlans != [] then "trunk"
    else "unused";

  # Every port ref as a normalized edge, flattened across the port set:
  #   { localPort; role; target; port; nic; }
  # `role` is the ref name (host/peer/…), `port`/`nic` the far side.
  links = ports:
    lib.concatLists (lib.mapAttrsToList (pname: p:
      lib.mapAttrsToList (role: ref:
        egregorLib.refNorm ref // { localPort = pname; inherit role; }
      ) p.refs
    ) ports);

  # Assertions for a switch's port refs: the target must exist, and if
  # the edge names an attachment point on the far side, that point must
  # exist too — a port on the target switch, an interface on the target
  # host. Core validates entity-level refs; port refs are nested inside
  # a type option, so the type has to ask for them to be checked.
  #
  # An edge that names no attachment point is still valid; it just says
  # less. Only what's claimed gets checked.
  linkAssertions = name: ports: egregore:
    lib.concatMap (l: let
      target = egregore.entities.${l.target} or null;
      # Closed keys read as "this kind has no such vocabulary" at their
      # null default — the old open-bag absence.
      targetPorts = if target == null then null else target.portNames or null;
      targetNics = if target == null then null else target.interfaceNames or null;
    in [
      {
        assertion = target != null;
        message =
          "switch '${name}' port '${l.localPort}' ref '${l.role}' → "
          + "'${l.target}' does not exist";
      }
    ]
    ++ lib.optional (l.port != null && targetPorts != null) {
      assertion = builtins.elem l.port targetPorts;
      message =
        "switch '${name}' port '${l.localPort}' links to "
        + "'${l.target}:${l.port}', which is not a port on '${l.target}'";
    }
    ++ lib.optional (l.nic != null && targetNics != null) {
      assertion = builtins.elem l.nic targetNics;
      message =
        "switch '${name}' port '${l.localPort}' links to interface "
        + "'${l.nic}' on '${l.target}', which declares no such interface "
        + "(has: ${lib.concatStringsSep ", " targetNics})";
    }) (links ports);
}
