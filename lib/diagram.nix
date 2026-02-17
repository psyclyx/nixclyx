# diagram.nix — Generate a Mermaid network diagram from topology data.
#
# mkMermaid :: lib -> topology -> string
#
# Pure function: no nixpkgs dependency beyond lib string helpers.
lib: topology: let
  inherit (builtins) attrNames filter hasAttr concatStringsSep length;
  inherit (lib) replaceStrings;

  # Sanitize node IDs: replace `-` with `_` for Mermaid compatibility.
  san = replaceStrings ["-"] ["_"];

  hosts = topology.hosts;
  hostNames = attrNames hosts;
  networks = topology.networks;
  networkNames = attrNames networks;

  hub = topology.vpn.hub;

  vpnHosts = filter (h: hasAttr "vpn" hosts.${h}) hostNames;
  spokes = filter (h: h != hub) vpnHosts;

  # Lab hosts have a labIndex and mac set.
  labHosts = filter (h: hasAttr "labIndex" hosts.${h}) hostNames;

  # Networks with a labIface — every lab host is in each of these.
  labNetworks = filter (n: hasAttr "labIface" networks.${n}) networkNames;

  standalone = filter (h:
    !(hasAttr "vpn" hosts.${h}) && !(hasAttr "labIndex" hosts.${h})
  ) hostNames;

  # The router is iyr — it has VPN with exportedRoutes into lab networks.
  router = "iyr";

  indent = n: concatStringsSep "" (builtins.genList (_: "  ") n);

  lines = ls: concatStringsSep "\n" (filter (l: l != "") ls);

  # --- Internet & hub ---
  internetSection = lines [
    "${indent 1}internet((Internet))"
    "${indent 1}internet --- |${hosts.${hub}.publicIPv4}| ${san hub}"
    "${indent 1}internet --- |${hosts.${hub}.publicIPv6}| ${san hub}"
  ];

  # --- VPN subgraph ---
  vpnNodes = concatStringsSep "\n" (map (h:
    "${indent 2}${san h}[${h}<br/>${hosts.${h}.vpn.address}]"
  ) vpnHosts);

  vpnLinks = concatStringsSep "\n" (map (s:
    "${indent 1}${san hub} -.-|WireGuard| ${san s}"
  ) spokes);

  vpnSubgraph = lines [
    "${indent 1}subgraph vpn[VPN Overlay — ${topology.vpn.subnet}]"
    vpnNodes
    "${indent 1}end"
    vpnLinks
  ];

  # --- Lab network subgraphs ---
  # Every lab host appears in every labIface-bearing network.
  # Node IDs are scoped per-network to allow the same host in multiple subgraphs.
  networkSubgraph = net: let
    info = networks.${net};
    iface = info.labIface;
    label =
      if hasAttr "vpnNat" info
      then "${net} — ${info.ipv4}<br/>1:1 NAT ${info.vpnNat}"
      else "${net} — ${info.ipv4}";
    memberNodes = concatStringsSep "\n" (map (h:
      "${indent 3}${san h}_${san net}[${h} / ${iface}]"
    ) labHosts);
  in lines [
    "${indent 2}subgraph ${san net}[${label}]"
    memberNodes
    "${indent 2}end"
  ];

  # main has no labIface — include it as an empty segment iyr routes to.
  mainSubgraph = lines [
    "${indent 2}subgraph main[main — ${networks.main.ipv4}]"
    "${indent 2}end"
  ];

  networkSubgraphs = concatStringsSep "\n"
    ([mainSubgraph] ++ map networkSubgraph labNetworks);

  routerLinks = concatStringsSep "\n"
    (["${indent 2}${san router} --- main"]
     ++ map (net: "${indent 2}${san router} --- ${san net}") labNetworks);

  # Show the 1:1 NAT link from VPN into rack-vpn.
  natLinks = concatStringsSep "\n" (filter (l: l != "") (map (net: let
    info = networks.${net};
  in
    if hasAttr "vpnNat" info
    then "${indent 1}${san router} -.-|1:1 NAT<br/>${info.vpnNat}| ${san net}"
    else ""
  ) labNetworks));

  labSubgraph = lines [
    "${indent 1}subgraph lab[Home Lab]"
    networkSubgraphs
    routerLinks
    "${indent 1}end"
    natLinks
  ];

  # --- Standalone hosts ---
  standaloneSection =
    if length standalone == 0 then ""
    else lines (map (h:
      "${indent 1}${san h}[${h}]"
    ) standalone);

in lines [
  "graph TD"
  internetSection
  ""
  vpnSubgraph
  ""
  labSubgraph
  ""
  standaloneSection
]
