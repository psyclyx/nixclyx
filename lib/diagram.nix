# diagram.nix — Generic Mermaid graph renderer.
#
# mkMermaid :: lib -> graph -> string
#
# Renders an abstract graph model to Mermaid markup.  Contains no domain
# knowledge — all topology interpretation belongs in the caller.
#
# Graph model:
#   { direction, nodes, edges, subgraphs, subgraphOrder, classes }
lib: graph: let
  inherit (builtins) attrNames filter hasAttr concatStringsSep;
  inherit (lib) replaceStrings mapAttrsToList;

  san = replaceStrings ["-"] ["_"];

  indent = n: concatStringsSep "" (builtins.genList (_: "  ") n);

  lines = ls: concatStringsSep "\n" (filter (l: l != "") ls);

  lbl = text: "|\"${text}\"|";

  shapeOpen = shape:
    if shape == "circle" then "((\""
    else if shape == "hexagon" then "{{\""
    else "[\"";
  shapeClose = shape:
    if shape == "circle" then "\"))"
    else if shape == "hexagon" then "\"}}"
    else "\"]";

  connector = style:
    if style == "dashed" then "-.-"
    else if style == "invisible" then "~~~"
    else "---";

  # Format a node reference in an edge — inline nodes include their declaration.
  nodeRef = id: let
    nodes = graph.nodes or {};
  in if hasAttr id nodes && (nodes.${id}.inline or false) then let
    n = nodes.${id};
    shape = n.shape or "rect";
  in "${san id}${shapeOpen shape}${n.label}${shapeClose shape}"
  else san id;

  renderEdge = depth: e: let
    conn = connector (e.style or "solid");
    fromRef = nodeRef e.from;
    toRef = nodeRef e.to;
    labelPart = if hasAttr "label" e && e.label != ""
      then " ${lbl e.label} "
      else " ";
  in "${indent depth}${fromRef} ${conn}${labelPart}${toRef}";

  renderNode = depth: id: n: let
    shape = n.shape or "rect";
  in "${indent depth}${san id}${shapeOpen shape}${n.label}${shapeClose shape}";

  collectMembers = sgs: builtins.concatLists (mapAttrsToList (_: sg:
    (sg.members or []) ++ collectMembers (sg.subgraphs or {})
  ) sgs);

  renderSubgraph = depth: id: sg: let
    nestedOrder = attrNames (sg.subgraphs or {});
    nestedSgs = map (nid:
      renderSubgraph (depth + 1) nid (sg.subgraphs or {}).${nid}
    ) nestedOrder;
    memberNodes = map (m:
      if hasAttr m (graph.nodes or {})
      then renderNode (depth + 1) m graph.nodes.${m}
      else "${indent (depth + 1)}${san m}"
    ) (sg.members or []);
    sgEdges = map (renderEdge (depth + 1)) (sg.edges or []);
    outerEdges = map (renderEdge depth) (sg.outerEdges or []);
  in lines ([
    "${indent depth}subgraph ${san id}[\"${sg.label}\"]"
  ] ++ nestedSgs ++ memberNodes ++ sgEdges ++ [
    "${indent depth}end"
  ] ++ outerEdges);

  subgraphs = graph.subgraphs or {};
  allSubgraphed = collectMembers subgraphs;

  sgOrder = graph.subgraphOrder or (attrNames subgraphs);
  renderedSubgraphs = map (id:
    renderSubgraph 1 id subgraphs.${id}
  ) sgOrder;

  topNodes = filter (id:
    !builtins.elem id allSubgraphed
    && !((graph.nodes or {}).${id}.inline or false)
  ) (attrNames (graph.nodes or {}));
  renderedTopNodes = map (id: renderNode 1 id graph.nodes.${id}) topNodes;

  renderedEdges = map (renderEdge 1) (graph.edges or []);

  classes = graph.classes or {};
  classDefs = mapAttrsToList (name: c:
    "classDef ${name} fill:${c.fill},stroke:${c.stroke},color:${c.color}"
  ) classes;

  classAssignments = builtins.concatLists (mapAttrsToList (name: _: let
    members = filter (id:
      hasAttr id (graph.nodes or {}) && (graph.nodes.${id}.class or null) == name
    ) (attrNames (graph.nodes or {}));
  in if members == [] then []
    else ["class ${concatStringsSep "," (map san members)} ${name}"]
  ) classes);

in lines ([
  "graph ${graph.direction or "TD"}"
] ++ renderedTopNodes ++ renderedEdges ++ renderedSubgraphs
  ++ classDefs ++ classAssignments)
