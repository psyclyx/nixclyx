# Entity type: Sodola web-managed switch.
{ lib, egregorLib, config, ... }:
let
  portDef = import ../lib/switch-port.nix { inherit lib; };
  portType = portDef.portType;

  pow2 = n: if n == 0 then 1 else 2 * pow2 (n - 1);
in
egregorLib.mkType {
  name = "sodola";
  topConfig = config;
  description = "Sodola web-managed switch (binary config format).";

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
    username = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Web UI auth username.";
    };
    password = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Web UI auth password.";
    };
  };

  attrs = name: entity: _top: let
    s = entity.sodola;
    active = lib.filterAttrs (_: p: portType p != "unused") s.ports;
  in {
    address = s.addresses.mgmt.ipv4;
    label = "${if s.identity != null then s.identity else name} (${s.model})";
    platform = "sodola";
    model = s.model;
    portCount = builtins.length (builtins.attrNames s.ports);
    activePortCount = builtins.length (builtins.attrNames active);
  };

  verbs = name: entity: top: let
    sw = entity.sodola;

    mgmt     = top.entities.mgmt;
    mgmtVlan = mgmt.network.vlan;
    mgmtGw   = mgmt.attrs.gateway4;
    mgmtPLen = mgmt.attrs.prefixLen;

    # Subnet mask from prefix length.
    maskOctet = bits:
      if bits >= 8 then 255
      else if bits <= 0 then 0
      else 256 - pow2 (8 - bits);
    mgmtMask = let p = mgmtPLen; in
      "${toString (maskOctet (lib.min p 8))}.${toString (maskOctet (lib.min (lib.max (p - 8) 0) 8))}.${toString (maskOctet (lib.min (lib.max (p - 16) 0) 8))}.${toString (maskOctet (lib.min (lib.max (p - 24) 0) 8))}";

    totalPorts = 9;
    allPortNums = lib.range 1 totalPorts;

    portCfgN = n: sw.ports.${"port${toString n}"} or {
      vlan = null; vlans = []; meta = { host = null; peer = null; description = null; };
    };

    # Collect all VLANs used by any port + management.
    switchVlans = let
      accessVlans = builtins.filter (v: v != null) (map (n: (portCfgN n).vlan) allPortNums);
      trunkVlans  = builtins.concatLists (map (n: (portCfgN n).vlans) allPortNums);
    in lib.sort builtins.lessThan (lib.unique ([1] ++ accessVlans ++ trunkVlans ++ [mgmtVlan]));

    # Which ports are members of a given VLAN.
    # Ports 1-8: member if access port on this VLAN or trunk carrying it.
    # Port 9: also member if its native VLAN matches (the binary has a
    # separate native bit for port 9 that the tool sets via _encode_port9).
    vlanMembers = vlan: builtins.filter (n: let
      p = portCfgN n;
      mode = portType p;
      native = if p.vlan != null then p.vlan else 1;
    in (mode == "access" && p.vlan == vlan)
       || (mode == "trunk" && builtins.elem vlan p.vlans)
       || (n == totalPorts && mode != "unused" && native == vlan)
    ) allPortNums;

    mkPort = n: let
      p = portCfgN n;
      mode = portType p;
    in {
      mode = if mode == "access" then "access" else "trunk";
      native_vlan = if mode == "access" then p.vlan else 1;
      speed = "auto";
    };

    projection = {
      network = {
        ip      = sw.addresses.mgmt.ipv4;
        netmask = mgmtMask;
        gateway = mgmtGw;
      };
      auth = { username = sw.username; };
      ports = map mkPort allPortNums;
      vlans = map (vlan: {
        id      = vlan;
        members = vlanMembers vlan;
        name    = "";
      }) switchVlans;
      model          = sw.model;
      mgmt_vlan_hint = 1;
      igmp_enabled   = false;
    };

    json = builtins.toJSON projection;
    mgmtIp = sw.addresses.mgmt.ipv4;

    # Sodola auth: cookie = md5(username + password).
    cookie = "${sw.username}=${builtins.hashString "md5" "${sw.username}${sw.password}"}";
    curlAuth = ''-b "${cookie}" -e "http://${mgmtIp}/"'';
    pullCmd = ''curl -sf --connect-timeout 5 ${curlAuth} \
  "http://${mgmtIp}/config_back.cgi?cmd=conf_backup"'';
  in {
    config-json = {
      description = "Output the switch configuration as JSON.";
      pure = true;
      impl = json;
    };
    generate-config = {
      description = "Generate Sodola binary backup (hex-encoded).";
      impl = ''sodola-config generate --hex <<'EGREGORE_EOF'
${json}
EGREGORE_EOF'';
    };
    pull = {
      description = "Download live config from switch (--raw for binary).";
      impl = ''
        if [[ "''${1:-}" == "--raw" ]]; then
          ${pullCmd}
        else
          ${pullCmd} | sodola-config parse
        fi'';
    };
    diff = {
      description = "Diff live switch config against desired config.";
      impl = ''
        live=$(${pullCmd} | sodola-config parse)
        desired=$(sodola-config generate <<'EGREGORE_EOF' | sodola-config parse
${json}
EGREGORE_EOF
)
        diff --color=auto -u <(echo "$live") <(echo "$desired") || true'';
    };
    deploy = {
      description = "Deploy config to switch (restore + reboot).";
      impl = ''
        echo "Generating config..." >&2
        tmpfile=$(mktemp)
        trap "rm -f $tmpfile" EXIT
        sodola-config generate <<'EGREGORE_EOF' > "$tmpfile"
${json}
EGREGORE_EOF

        echo "Uploading to ${mgmtIp}..." >&2
        curl -sf --connect-timeout 5 ${curlAuth} \
          -F "submitFile=@$tmpfile" \
          "http://${mgmtIp}/config_back.cgi?cmd=conf_restore" >/dev/null

        echo "Rebooting switch..." >&2
        curl -sf --connect-timeout 5 ${curlAuth} \
          -d "cmd=reboot" \
          "http://${mgmtIp}/reboot.cgi" >/dev/null || true

        echo "Deploy complete. Switch will be unreachable for ~30s." >&2'';
    };
    port-map = {
      description = "Show human-readable port map.";
      pure = true;
      impl = let
        allNames = lib.sort builtins.lessThan (builtins.attrNames sw.ports);
      in ''
        # Sodola Port Configuration for ${sw.model} (${if sw.identity != null then sw.identity else name})
        # Management: ${sw.addresses.mgmt.ipv4} on VLAN ${toString mgmtVlan}
      '' + lib.concatStringsSep "\n" (map (pname: let
        p = sw.ports.${pname};
        mode = portType p;
        vlan = if mode == "access" then toString p.vlan
               else if mode == "trunk" then
                 (if p.vlans != [] then lib.concatStringsSep "," (map toString p.vlans) else "all")
               else "-";
      in "#   ${pname}: ${mode} ${vlan} — ${portDef.portLabel p}") allNames);
    };
  };
}
