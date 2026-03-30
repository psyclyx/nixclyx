# Entity type: MikroTik SwOS switch.
{ lib, egregorLib, config, ... }:
let
  portDef = import ../lib/switch-port.nix { inherit lib; };
  portType = portDef.portType;
  portLabel = portDef.portLabel;
in
egregorLib.mkType {
  name = "swos";
  topConfig = config;
  description = "MikroTik SwOS managed switch.";

  options = {
    model = lib.mkOption { type = lib.types.str; default = ""; };
    identity = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
    addresses = lib.mkOption {
      type = lib.types.submodule {
        options.mgmt = lib.mkOption {
          type = lib.types.submodule {
            options.ipv4 = lib.mkOption { type = lib.types.str; };
          };
        };
      };
    };
    ports = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule portDef.module);
      default = {};
    };
  };

  attrs = name: entity: _top: let
    s = entity.swos;
    active = lib.filterAttrs (_: p: portType p != "unused") s.ports;
  in {
    address = s.addresses.mgmt.ipv4;
    label = "${if s.identity != null then s.identity else name} (${s.model})";
    platform = "swos";
    model = s.model;
    portCount = builtins.length (builtins.attrNames s.ports);
    activePortCount = builtins.length (builtins.attrNames active);
  };

  verbs = name: entity: top: let
    sw = entity.swos;
    identity = if sw.identity != null then sw.identity else name;

    mgmtVlan = top.entities.mgmt.network.vlan;
    mgmtIp   = sw.addresses.mgmt.ipv4;

    # CSS326: 24 copper + 2 SFP+ = 26 ports.
    totalPorts = 26;
    allIndices = lib.range 0 (totalPorts - 1);
    allPorts1  = lib.range 1 totalPorts;

    portName = idx:
      if idx < 24 then "ether${toString (idx + 1)}"
      else if idx == 24 then "sfp-sfpplus1"
      else "sfp-sfpplus2";

    cfgAt = idx: let n = portName idx; in
      sw.ports.${n} or { vlan = null; vlans = []; meta = { host = null; peer = null; description = null; }; };
    modeAt = idx: portType (cfgAt idx);

    # Collect all VLANs used across all ports + management.
    switchVlans = let
      accessVlans = builtins.filter (v: v != null) (map (i: (cfgAt i).vlan) allIndices);
      trunkVlans  = builtins.concatLists (map (i: (cfgAt i).vlans) allIndices);
    in lib.sort builtins.lessThan (lib.unique (accessVlans ++ trunkVlans ++ [mgmtVlan]));

    # VLAN membership: 1-based port numbers.
    vlanMembers = vlan: builtins.filter (n: let
      idx = n - 1;
      p = cfgAt idx;
      mode = modeAt idx;
    in (mode == "access" && p.vlan == vlan)
       || (mode == "trunk" && builtins.elem vlan p.vlans)
    ) allPorts1;

    # Per-port config for the SwOS tool JSON schema.
    mkPort = idx: let
      p = cfgAt idx;
      mode = modeAt idx;
      isEnabled = mode != "unused";
      label = if isEnabled then builtins.substring 0 16 (portLabel p) else "";
    in {
      auto_negotiate   = true;
      blocked          = false;
      cable_mode       = 0;
      default_vid      = if mode == "access" then p.vlan else 1;
      duplex           = true;
      enabled          = isEnabled;
      flow_control_rx  = false;
      flow_control_tx  = true;
      forward_multicast = true;
      forward_to       = builtins.filter (n: n != (idx + 1)) allPorts1;
      ingress_rate     = 0;
      input_mirror     = false;
      lacp_group       = 0;
      lacp_mode        = 0;
      mac_lock         = false;
      mac_lock_filter  = false;
      name             = label;
      output_mirror    = false;
      qos_type         = 0;
      sfp              = idx >= 24;
      source_unknown   = false;
      speed            = 0;
      storm_rate       = 100;
      vlan_mode        = if isEnabled then 2 else 0;
      vlan_receive     = 0;
    };

    projection = {
      ports = map mkPort allIndices;
      vlans = map (vlan: {
        id             = vlan;
        igmp           = false;
        learning       = true;
        members        = vlanMembers vlan;
        mirror         = false;
        name           = "";
        port_isolation = false;
      }) switchVlans;
      system = {
        admin_vlan                = mgmtVlan;
        all_ports                 = allPorts1;
        allow_from_all_addresses  = false;
        allow_from_all_mgmt       = false;
        auto_info                 = true;
        discovery                 = true;
        drop_tagged               = allPorts1;
        frame_size_check          = false;
        identity                  = identity;
        igmp_flood                = false;
        igmp_query                = true;
        igmp_snooping             = false;
        igmp_vlan_exclusive       = true;
        ip                        = mgmtIp;
        ip_type                   = 1;
        ivl                       = false;
        management                = true;
        poe                       = false;
        port_discovery            = allPorts1;
        stp_cost_mode             = 0;
        stp_priority              = 32768;
        watchdog                  = true;
      };
      password     = "";
      snmp         = { community = "public"; contact = ""; enabled = true; location = ""; };
      rstp         = { enabled_ports = allPorts1; };
      mirror       = { target_port = 1; };
      filter_vid   = 0;
      acl          = [];
      hosts        = [];
    };

    json = builtins.toJSON projection;

    # SwOS backup endpoint uses HTTP basic auth (default admin / no password).
    pullCmd = ''curl -sf --connect-timeout 5 \
  -u "admin:" \
  "http://${mgmtIp}/backup.swb"'';
  in {
    config-json = {
      description = "Output the switch configuration as JSON.";
      pure = true;
      impl = json;
    };
    generate-config = {
      description = "Generate SwOS .swb backup.";
      impl = ''swos-config generate <<'EGREGORE_EOF'
${json}
EGREGORE_EOF'';
    };
    pull-config = {
      description = "Download live config from switch, output as JSON.";
      impl = ''${pullCmd} | swos-config parse'';
    };
    pull-raw = {
      description = "Download raw .swb backup from switch.";
      impl = pullCmd;
    };
    diff-config = {
      description = "Diff live switch config against desired config.";
      impl = ''
        live=$(${pullCmd} | swos-config parse)
        desired=$(swos-config generate <<'EGREGORE_EOF' | swos-config parse
${json}
EGREGORE_EOF
)
        diff --color=auto -u <(echo "$live") <(echo "$desired") || true'';
    };
    port-map = {
      description = "Show human-readable port map.";
      pure = true;
      impl = let
        allNames = lib.sort builtins.lessThan (builtins.attrNames sw.ports);
      in ''
        # SwOS Port Configuration for ${sw.model} (${identity})
        # Management: ${mgmtIp} on VLAN ${toString mgmtVlan}
      '' + lib.concatStringsSep "\n" (map (pname: let
        p = sw.ports.${pname};
        mode = portType p;
        vlan = if mode == "access" then toString p.vlan
               else if mode == "trunk" then "all"
               else "-";
      in "#   ${lib.fixedWidthString 15 " " pname}: ${lib.fixedWidthString 8 " " mode} ${lib.fixedWidthString 6 " " vlan} ${portLabel p}") allNames);
    };
  };
}
