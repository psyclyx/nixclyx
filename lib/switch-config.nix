# switch-config.nix — Generate complete, restorable switch configurations.
#
# Pure Nix string interpolation: no pkgs, no derivations.
#
# Usage:
#   let
#     fleet = import ./data/fleet;
#     gen = import ./lib/switch-config.nix lib fleet;
#   in
#     gen.routeros "mdf-agg01"   # -> Complete RouterOS .rsc script
#     gen.routeros "idf-dist01"  # -> CRS305 RouterOS .rsc script
#     gen.swos "mdf-acc01"       # -> SwOS .swb backup file content
#
lib: fleetData:
let
  networks = fleetData.topology.networks;
  hosts = fleetData.hosts;
  devices = fleetData.devices;

  # ── Encoding helpers ────────────────────────────────────────────

  # Power of 2.
  pow2 = n: if n == 0 then 1 else 2 * pow2 (n - 1);

  # Left-pad a string to at least `width` characters with `fill`.
  lpad = width: fill: s:
    let len = builtins.stringLength s;
    in if len >= width then s
       else lpad width fill (fill + s);

  # Integer to hex string with minimum width (no 0x prefix), lowercase.
  toHex = width: n: lpad width "0" (lib.toLower (lib.toHexString n));

  # Printable ASCII (codes 32–126) as a character list for ord() lookups.
  asciiRef = lib.stringToCharacters
    " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";

  # Character → integer code point.
  charCode = c:
    let idx = lib.lists.findFirstIndex (x: x == c) null asciiRef;
    in if idx == null then throw "Non-printable ASCII character"
       else idx + 32;

  # Hex-encode a string (each char → 2 hex digits), for SwOS backup format.
  hexEncodeString = s:
    lib.concatStrings (map (c: toHex 2 (charCode c)) (lib.stringToCharacters s));

  # IPv4 string → little-endian 32-bit hex (SwOS format).
  ipToLE32Hex = ip: let
    octets = map lib.toInt (lib.splitString "." ip);
    val = builtins.elemAt octets 0
        + builtins.elemAt octets 1 * 256
        + builtins.elemAt octets 2 * 65536
        + builtins.elemAt octets 3 * 16777216;
  in "0x${toHex 8 val}";

  # Bitmask from a list of bit positions.
  bitmask = positions: builtins.foldl' (acc: pos: acc + pow2 pos) 0 positions;

  # ── Port helpers ────────────────────────────────────────────────

  # All VLAN IDs sorted (network VLANs + transit).
  transitVlan = fleetData.topology.conventions.transitVlan or null;
  networkVlans = lib.mapAttrsToList (_: net: net.vlan) networks;
  allVlans = lib.sort builtins.lessThan
    (lib.unique (networkVlans ++ lib.optional (transitVlan != null) transitVlan));

  # Map network name → VLAN ID.
  vlanOf = name: networks.${name}.vlan;

  # Resolve a port's VLAN.
  #   { host; interface; }       → VLAN from network name
  #   { type = "access"; vlan; } → explicit VLAN ID (modem, AP drop, etc.)
  portVlan = port:
    if port ? host then vlanOf port.interface
    else if port ? vlan then port.vlan
    else null;

  # Natural sort for port names: extract trailing digits for numeric comparison.
  portSortKey = name: let
    digits = builtins.match ".*[^0-9]([0-9]+)$" name;
    prefix = builtins.match "(.*[^0-9])[0-9]+$" name;
  in if digits == null then { p = name; n = 0; }
     else { p = builtins.head prefix; n = lib.toInt (builtins.head digits); };

  portSort = a: b: let
    ka = portSortKey a;
    kb = portSortKey b;
  in if ka.p == kb.p then ka.n < kb.n
     else ka.p < kb.p;

  sortPorts = lib.sort portSort;

  # Classify a port.
  portType = port:
    if port ? type then port.type    # "trunk", "access", or "unused"
    else "access";                   # has host + interface → host access

  # Describe a port for comments.
  portLabel = port:
    if port ? host then "${port.host} ${port.interface}"
    else if port ? description then port.description
    else if portType port == "access" then "access VLAN ${toString port.vlan}"
    else if portType port == "trunk" then "trunk to ${port.peer}"
    else "unused";

  # Strip prefix from a CIDR (e.g. "10.0.240.0/24" → "10.0.240.0").
  cidrAddr = cidr: builtins.head (lib.splitString "/" cidr);

  # Extract prefix length from CIDR string.
  cidrLen = cidr: lib.toInt (builtins.elemAt (lib.splitString "/" cidr) 1);

  # ── Hardware model port lists ───────────────────────────────────
  # Every physical port on each model, for complete config generation.
  # Ports not in fleet data are treated as unused/disabled.

  modelPorts = {
    "CRS326-24S+2Q+RM" =
      (map (i: "sfp-sfpplus${toString i}") (lib.range 1 24))
      ++ (lib.concatMap (q:
        map (s: "qsfpplus${toString q}-${toString s}") (lib.range 1 4)
      ) (lib.range 1 2));

    "CRS305-1G-4S+IN" =
      map (i: "sfp-sfpplus${toString i}") (lib.range 1 4);

    "CSS326-24G-2S+RM" =
      (map (i: "ether${toString i}") (lib.range 1 24))
      ++ ["sfp-sfpplus1" "sfp-sfpplus2"];
  };


  # ══════════════════════════════════════════════════════════════════
  # ── RouterOS generator (.rsc script) ─────────────────────────────
  # ══════════════════════════════════════════════════════════════════

  routeros = switchName: let
    sw = devices.${switchName};
    ports = sw.ports;
    identity = sw.identity or switchName;

    # PoE-in port (e.g. CRS305 ether1) — not a switching port.
    poeIn = sw.poeInPort or null;
    isPoeIn = name: poeIn != null && name == poeIn;

    # All hardware ports; fleet-assigned + unassigned, excluding PoE-in.
    hwPorts = modelPorts.${sw.model} or (builtins.attrNames ports);
    allPortNames = builtins.filter (n: !isPoeIn n) (sortPorts hwPorts);

    # Port config: fleet data or implicit unused.
    portCfg = name: ports.${name} or { type = "unused"; };

    accessPorts  = builtins.filter (n: portType (portCfg n) == "access") allPortNames;
    trunkPorts   = builtins.filter (n: portType (portCfg n) == "trunk") allPortNames;
    unusedPorts  = builtins.filter (n: portType (portCfg n) == "unused") allPortNames;
    activePorts  = builtins.filter (n: portType (portCfg n) != "unused") allPortNames;

    mgmtVlan = vlanOf "mgmt";
    mgmtIp   = sw.addresses.mgmt.ipv4;
    mgmtNet  = cidrAddr networks.mgmt.ipv4;
    mgmtGw   = let parts = lib.splitString "." mgmtNet;
               in "${builtins.elemAt parts 0}.${builtins.elemAt parts 1}.${builtins.elemAt parts 2}.${toString fleetData.topology.conventions.gatewayOffset}";
    mgmtPLen = cidrLen networks.mgmt.ipv4;

    # Group access ports by VLAN.
    accessByVlan = let
      pairs = map (name: {
        vlan = portVlan (portCfg name);
        port = name;
      }) accessPorts;
    in builtins.groupBy (p: toString p.vlan) pairs;

    # VLANs actually used on this switch (access + trunk carry all).
    usedVlans = let
      accessVlans = lib.unique (map (n: portVlan (portCfg n)) accessPorts);
      trunkVlans = if trunkPorts != [] then allVlans else [];
    in lib.sort builtins.lessThan (lib.unique (accessVlans ++ trunkVlans ++ [mgmtVlan]));

    portList = names: builtins.concatStringsSep "," names;

    # ── Script sections ──

    header = ''
      # RouterOS configuration for ${sw.model} (${switchName})
      # Generated from fleet data — do not edit manually.
      #
      # Port map:
      ${lib.concatStringsSep "\n" (map (n: "#   ${n}: ${portLabel (portCfg n)}${
        let p = portCfg n; in
        if portType p == "access" then " (VLAN ${toString (portVlan p)})" else ""
      }") activePorts)}
      #
    '';

    system = ''
      # ── System ──
      /system identity set name="${identity}"
      /system clock set time-zone-name=America/Los_Angeles
      /ip dns set servers=${mgmtGw}
      /ip ssh set host-key-type=ed25519
      /snmp set enabled=yes
    '';

    bridge = ''
      # ── Bridge ──
      /interface bridge
      add name=bridge1 protocol-mode=none igmp-snooping=yes
    '';

    bridgePorts = ''
      # ── Bridge ports ──
      /interface bridge port
    '' + lib.concatStringsSep "\n" (map (name: let
      p = portCfg name;
      mode = portType p;
      pvid = if mode == "access" then toString (portVlan p) else "1";
      comment = portLabel p;
    in
      "add bridge=bridge1 interface=${name} pvid=${pvid} comment=\"${comment}\""
    ) activePorts) + "\n";

    vlanTable = ''
      # ── VLAN table ──
      /interface bridge vlan
    '' + lib.concatStringsSep "\n" (map (vlan: let
      vlanStr = toString vlan;
      aPorts = if accessByVlan ? ${vlanStr}
               then map (p: p.port) accessByVlan.${vlanStr}
               else [];
      tPorts = trunkPorts;
      tagged = tPorts ++ (if vlan == mgmtVlan then ["bridge1"] else []);
      untagged = aPorts;
    in
      "add bridge=bridge1 vlan-ids=${vlanStr}"
      + (if tagged != [] then " tagged=${portList tagged}" else "")
      + (if untagged != [] then " untagged=${portList untagged}" else "")
    ) usedVlans) + "\n";

    mgmtInterface = ''
      # ── Management ──
      /interface vlan
      add interface=bridge1 name=vlan${toString mgmtVlan} vlan-id=${toString mgmtVlan}

      /ip address
      add address=${mgmtIp}/${toString mgmtPLen} interface=vlan${toString mgmtVlan} network=${mgmtNet}

      /ip route
      add disabled=yes dst-address=0.0.0.0/0 gateway=${mgmtGw}
    '';

    enableVlanFiltering = ''
      # ── Enable VLAN filtering (must be LAST to avoid lockout) ──
      /interface bridge set bridge1 vlan-filtering=yes
    '';

    disableUnused = if unusedPorts == [] then "" else ''
      # ── Disable unused ports ──
      /interface ethernet
    '' + lib.concatStringsSep "\n" (map (name:
      "set [find default-name=${name}] disabled=yes"
    ) unusedPorts) + "\n";

  in header + system + "\n" + bridge + "\n" + bridgePorts + "\n" + vlanTable
     + "\n" + mgmtInterface + "\n" + disableUnused + "\n" + enableVlanFiltering;


  # ══════════════════════════════════════════════════════════════════
  # ── SwOS generator (.swb backup file) ────────────────────────────
  # ══════════════════════════════════════════════════════════════════

  swos = switchName: let
    sw = devices.${switchName};
    ports = sw.ports;
    identity = sw.identity or switchName;

    totalPorts = 26; # CSS326: 24 ether + 2 SFP+
    allIndices = lib.range 0 (totalPorts - 1);
    allBits = pow2 totalPorts - 1; # 0x03ffffff

    # Port index mapping: ether1=0, ..., ether24=23, sfp-sfpplus1=24, sfp-sfpplus2=25
    portIndex = name:
      if lib.hasPrefix "ether" name then
        (lib.toInt (lib.removePrefix "ether" name)) - 1
      else if name == "sfp-sfpplus1" then 24
      else if name == "sfp-sfpplus2" then 25
      else throw "Unknown CSS326 port: ${name}";

    # Port name from index (inverse).
    portName = idx:
      if idx < 24 then "ether${toString (idx + 1)}"
      else if idx == 24 then "sfp-sfpplus1"
      else "sfp-sfpplus2";

    # Port config for each index.
    cfgAt = idx: let name = portName idx;
      in ports.${name} or { type = "unused"; };
    modeAt = idx: portType (cfgAt idx);

    mgmtVlan = vlanOf "mgmt";
    mgmtIp   = sw.addresses.mgmt.ipv4;

    # VLANs present on this switch (from access ports + trunk carries all).
    hasTrunk = builtins.any (idx: modeAt idx == "trunk") allIndices;
    accessVlanSet = lib.unique (builtins.filter (v: v != null)
      (map (idx: portVlan (cfgAt idx)) allIndices));
    switchVlans = lib.sort builtins.lessThan
      (lib.unique ((if hasTrunk then allVlans else accessVlanSet) ++ [mgmtVlan]));

    # Bitmask of ports that are members of a given VLAN.
    vlanMemberBits = vlan:
      bitmask (builtins.filter (idx: let
        mode = modeAt idx;
        p = cfgAt idx;
      in (mode == "access" && portVlan p == vlan)
         || (mode == "trunk")
      ) allIndices);

    # Enable bitmask: all non-unused ports.
    enableBits = bitmask
      (builtins.filter (idx: modeAt idx != "unused") allIndices);

    # Hex formatting helpers.
    h2 = n: "0x${toHex 2 n}";
    h8 = n: "0x${toHex 8 n}";

    # Per-port arrays (26 elements each), comma-separated.
    mkArray = f: "[${builtins.concatStringsSep "," (map f allIndices)}]";

    # ── vlan.b ──
    vlanEntries = map (vlan:
      "{nm:'',mbr:${h8 (vlanMemberBits vlan)},vid:${h2 vlan},piso:0x00,lrn:0x01,mrr:0x00,igmp:0x00}"
    ) switchVlans;
    vlanSection = "vlan.b:[${builtins.concatStringsSep "," vlanEntries}]";

    # ── lacp.b ──
    lacpSection = "lacp.b:{mode:${mkArray (_: "0x00")},sgrp:${mkArray (_: "0x00")}}";

    # ── .pwd.b ──
    pwdSection = ".pwd.b:{pwd:''}";

    # ── snmp.b ──
    snmpSection = "snmp.b:{en:0x01,com:'${hexEncodeString "public"}',ci:'',loc:''}";

    # ── rstp.b ──
    rstpSection = "rstp.b:{ena:${h8 allBits}}";

    # ── link.b ──
    portNameFor = idx: let
      p = cfgAt idx;
      mode = modeAt idx;
    in if mode == "unused" then "" else portLabel p;

    linkSection = "link.b:{"
      + "en:${h8 enableBits}"
      + ",blkp:0x00"
      + ",an:${h8 allBits}"
      + ",dpxc:${h8 allBits}"
      + ",fctc:${h8 allBits}"
      + ",fctr:0x00"
      + ",spdc:${mkArray (_: "0x00")}"
      + ",cm:${mkArray (_: "0x00")}"
      + ",qtyp:${mkArray (_: "0x00")}"
      + ",nm:[${builtins.concatStringsSep "," (map (idx:
          "'${hexEncodeString (portNameFor idx)}'"
        ) allIndices)}]"
      + ",sfpr:${mkArray (idx: if idx >= 24 then "0x01" else "0x00")}"
      + "}";

    # ── fwd.b ──
    fwdMask = idx: allBits - pow2 idx;

    vlanModeAt = idx: let mode = modeAt idx;
      in if mode == "access" then "0x02"
         else if mode == "trunk" then "0x02"
         else "0x00";

    vlanRecvAt = idx: let mode = modeAt idx;
      in if mode == "access" then "0x00"
         else if mode == "trunk" then "0x00"
         else "0x00";

    defaultVidAt = idx: let
      mode = modeAt idx;
      p = cfgAt idx;
    in if mode == "access" then h2 (portVlan p)
       else "0x01";

    fwdSection = "fwd.b:{"
      + builtins.concatStringsSep "," (map (idx:
          "fp${toString (idx + 1)}:${h8 (fwdMask idx)}"
        ) allIndices)
      + ",lck:0x00,lckf:0x00"
      + ",imr:0x00,omr:0x00,mrto:0x01"
      + ",vlan:${mkArray (idx: vlanModeAt idx)}"
      + ",vlni:${mkArray (idx: vlanRecvAt idx)}"
      + ",dvid:${mkArray (idx: defaultVidAt idx)}"
      + ",fvid:0x00"
      + ",srt:${mkArray (_: "0x64")}"
      + ",suni:0x00"
      + ",fmc:${h8 allBits}"
      + ",ir:${mkArray (_: "0x00")}"
      + "}";

    # ── sys.b ──
    sysSection = "sys.b:{"
      + "id:'${hexEncodeString identity}'"
      + ",wdt:0x01"
      + ",dsc:0x01"
      + ",pdsc:${h8 allBits}"
      + ",ivl:0x00"
      + ",alla:0x00"
      + ",allm:0x00"
      + ",avln:${h2 mgmtVlan}"
      + ",allp:${h8 allBits}"
      + ",mgmt:0x01"
      + ",prio:0x8000"
      + ",cost:0x00"
      + ",frmc:0x00"
      + ",poe:0x00"
      + ",igmp:0x00"
      + ",igmq:0x01"
      + ",igfl:0x00"
      + ",igve:0x01"
      + ",ip:${ipToLE32Hex mgmtIp}"
      + ",dtrp:${h8 allBits}"
      + ",ainf:0x01"
      + ",iptp:0x01"
      + "}";

    # ── acl.b, host.b ──
    aclSection = "acl.b:[]";
    hostSection = "host.b:[]";

    # ── Complete backup ──
    backup = builtins.concatStringsSep ","
      [ vlanSection lacpSection pwdSection snmpSection rstpSection
        linkSection fwdSection sysSection aclSection hostSection ];

    # Human-readable port map (for documentation).
    portMap = let
      allNames = sortPorts (builtins.attrNames ports);
    in ''
      # SwOS Port Configuration for ${sw.model} (${switchName})
      # Generated from fleet data — do not edit manually.
      #
      # Management: ${mgmtIp} on VLAN ${toString mgmtVlan}
      #
      # ┌─────────────────┬──────────┬────────┬──────────────────────────────┐
      # │ Port            │ Mode     │ VLAN   │ Description                  │
      # ├─────────────────┼──────────┼────────┼──────────────────────────────┤
    '' + lib.concatStringsSep "\n" (map (name: let
      p = ports.${name};
      mode = portType p;
      vlan = if mode == "access" then toString (portVlan p) else
             if mode == "trunk" then "all" else "-";
      desc = portLabel p;
      namePad = lib.fixedWidthString 15 " " name;
      modePad = lib.fixedWidthString 8 " " mode;
      vlanPad = lib.fixedWidthString 6 " " vlan;
    in
      "# │ ${namePad} │ ${modePad} │ ${vlanPad} │ ${desc}"
    ) allNames) + "\n"
    + ''
      # └─────────────────┴──────────┴────────┴──────────────────────────────┘
    '';

  in {
    inherit backup portMap;
  };


  # ── Enriched port data ──────────────────────────────────────────

  enrichPorts = switchName: let
    sw = devices.${switchName};
  in lib.mapAttrs (portName: port: port // {
    type = portType port;
    vlan = if portType port == "access" then portVlan port else null;
    comment = portLabel port;
  }) sw.ports;

in {
  inherit routeros swos enrichPorts;

  # List all switches of a given platform.
  byPlatform = platform:
    lib.filterAttrs (_: sw: sw.platform == platform) devices;

  # Generate configs for all switches of a platform.
  allRouterOS = lib.concatStringsSep "\n\n" (
    lib.mapAttrsToList (name: _: routeros name)
      (lib.filterAttrs (_: sw: sw.platform == "routeros") devices)
  );
}
