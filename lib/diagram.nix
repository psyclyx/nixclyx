# diagram.nix — Generate a Mermaid network diagram from topology data.
#
# mkMermaid :: lib -> topology -> string
#
# Pure function: no nixpkgs dependency beyond lib string helpers.
lib: topology: let
  inherit (builtins) attrNames filter hasAttr concatStringsSep length elem;
  inherit (lib) mapAttrsToList concatMapStringsSep replaceStrings;

  # Sanitize node IDs: replace `-` with `_` for Mermaid compatibility.
  san = replaceStrings ["-"] ["_"];

  hosts = topology.hosts;
  hostNames = attrNames hosts;

  hub = topology.vpn.hub;

  vpnHosts = filter (h: hasAttr "vpn" hosts.${h}) hostNames;
  spokes = filter (h: h != hub) vpnHosts;

  labHosts = filter (h: hasAttr "network" hosts.${h}) hostNames;
  networkNames = attrNames topology.networks;

  labHostsInNetwork = net:
    filter (h: hosts.${h}.network == net) labHosts;

  standalone = filter (h:
    !(hasAttr "vpn" hosts.${h}) && !(hasAttr "network" hosts.${h})
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
  networkSubgraph = net: let
    info = topology.networks.${net};
    members = labHostsInNetwork net;
    memberNodes = concatStringsSep "\n" (map (h:
      "${indent 3}${san h}[${h}]"
    ) members);
  in
    if length members == 0 then
      lines [
        "${indent 2}subgraph ${san net}[${net} — ${info.ipv4}]"
        "${indent 2}end"
      ]
    else
      lines [
        "${indent 2}subgraph ${san net}[${net} — ${info.ipv4}]"
        memberNodes
        "${indent 2}end"
      ];

  populatedNetworks = filter (net:
    length (labHostsInNetwork net) > 0
  ) networkNames;

  # Include main network even if no hosts — iyr routes to it.
  diagramNetworks = let
    all = filter (net:
      length (labHostsInNetwork net) > 0 || net == "main"
    ) networkNames;
  in all;

  networkSubgraphs = concatStringsSep "\n" (map networkSubgraph diagramNetworks);

  routerLinks = concatStringsSep "\n" (map (net:
    "${indent 2}${san router} --- ${san net}"
  ) diagramNetworks);

  labSubgraph = lines [
    "${indent 1}subgraph lab[Home Lab]"
    networkSubgraphs
    routerLinks
    "${indent 1}end"
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
