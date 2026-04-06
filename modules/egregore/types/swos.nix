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
            options.ipv4 = lib.mkOption { type = lib.types.str; default = ""; };
          };
          default = {};
        };
      };
      default = {};
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
      lacp_group       = p.lacpGroup;
      lacp_mode        = if p.lacpGroup != 0 then 1 else 0;  # passive LACP when grouped
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
        drop_tagged               = builtins.filter (n: modeAt (n - 1) != "trunk") allPorts1;
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

    # SwOS uses HTTP digest auth (default admin / no password).
    curlAuth = ''--digest -u "admin:"'';
    pullCmd = ''curl -sf --connect-timeout 5 ${curlAuth} \
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
    pull = {
      description = "Download live config from switch (--raw for .swb).";
      impl = ''
        if [[ "''${1:-}" == "--raw" ]]; then
          ${pullCmd}
        else
          ${pullCmd} | swos-config parse
        fi'';
    };
    diff = {
      description = "Diff live switch config against desired config.";
      impl = ''
        live=$(${pullCmd} | swos-config parse)
        desired=$(swos-config generate <<'EGREGORE_EOF' | swos-config parse
${json}
EGREGORE_EOF
)
        diff --color=auto -u <(echo "$live") <(echo "$desired") || true'';
    };
    deploy = {
      description = "Deploy config to switch via per-section POST.";
      impl = ''
        echo "Generating config..." >&2
        tmpfile=$(mktemp --suffix=.swb)
        trap 'rm -f "$tmpfile"' EXIT
        swos-config generate <<'EGREGORE_EOF' > "$tmpfile"
${json}
EGREGORE_EOF

        echo "Deploying to ${mgmtIp}..." >&2
        # SwOS ignores multipart backup uploads; POST each section individually
        python3 - "$tmpfile" "${mgmtIp}" << 'DEPLOY_EOF'
import re, subprocess, sys

data = open(sys.argv[1]).read()
mgmt_ip = sys.argv[2]
sections = []
i = 0
while i < len(data):
    m = re.match(r'(\w+\.b):', data[i:])
    if not m:
        i += 1
        continue
    name = m.group(1)
    start = i + len(m.group(0))
    depth = 0
    for j, c in enumerate(data[start:]):
        if c in '{[': depth += 1
        elif c in '}]': depth -= 1
        if depth == 0:
            content = data[start:start+j+1]
            sections.append((name, content))
            i = start + j + 2  # skip closing + comma
            break
    else:
        break

failed = False
for name, content in sections:
    r = subprocess.run(
        ['curl', '-sf', '--connect-timeout', '5', '--max-time', '10',
         '--digest', '-u', 'admin:',
         '-X', 'POST', '-d', content,
         f'http://{mgmt_ip}/' + name],
        capture_output=True, timeout=15
    )
    status = 'OK' if r.returncode == 0 else 'FAIL'
    print(f'  {status}: {name}', file=sys.stderr)
    if r.returncode != 0:
        failed = True
if failed:
    sys.exit(1)
DEPLOY_EOF

        echo "Deploy complete." >&2'';
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
