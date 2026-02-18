# routeros.nix — Generate a RouterOS configuration script.
#
# mkRouterOS :: lib -> [section] -> string
#
# section = {
#   path     : string       — RouterOS command path (e.g. "/interface bonding")
#   commands : [{
#     action : string       — "set" | "add" | "remove" (default: "add")
#     find   : attrset?     — for "set [ find key=val ] ..." pattern
#     values : attrset      — key-value pairs
#   }]
# }
#
# Value types in `values` / `find`:
#   string     → bare or quoted (auto-detected)
#   int        → decimal
#   bool       → yes / no
#   [value]    → comma-separated
#   null       → key omitted
#
# Produces a RouterOS script matching `/export` format.
lib: sections: let
  inherit (builtins) attrNames concatStringsSep filter hasAttr
    isBool isInt isList isString map sort toString;
  inherit (lib) optionalString;

  # --- Value serialization --------------------------------------------------

  # Quote values containing spaces or double-quotes; bare otherwise.
  needsQuote = s:
    s == "" || builtins.match "[^ \"]+" s == null;

  serializeValue = v:
    if v == null then null
    else if isBool v then (if v then "yes" else "no")
    else if isInt v then toString v
    else if isList v then concatStringsSep "," (map serializeValue v)
    else if isString v then (if needsQuote v then "\"${v}\"" else v)
    else toString v;

  # Render key=value pairs, sorted for determinism, skipping nulls.
  renderKV = attrs: let
    keys = sort (a: b: a < b) (attrNames attrs);
    pairs = filter (p: p != null) (map (k: let
      v = serializeValue attrs.${k};
    in if v == null then null else "${k}=${v}") keys);
  in concatStringsSep " " pairs;

  # --- Command rendering ----------------------------------------------------

  renderCommand = cmd: let
    action = cmd.action or "add";
    findClause = if hasAttr "find" cmd && cmd.find != null
      then " [ find ${renderKV cmd.find} ]"
      else "";
    values = renderKV (cmd.values or {});
  in "${action}${findClause}${optionalString (values != "") " ${values}"}";

  # --- Section rendering ----------------------------------------------------

  renderSection = section: let
    cmds = section.commands or [];
    rendered = map renderCommand cmds;
  in if cmds == [] then ""
    else concatStringsSep "\n" ([ section.path ] ++ rendered);

  rendered = filter (s: s != "") (map renderSection sections);

in concatStringsSep "\n\n" rendered + "\n"
