#!/usr/bin/env python3
"""Render NixOS/Home/Darwin options.json into a compact collapsible HTML tree."""

import argparse
import html
import json
import re
import sys


def shorten_type(t):
    """Convert NixOS type descriptions to compact notation."""
    t = t.strip()

    # function
    m = re.match(r"^function that evaluates to a\(n\) (.+)$", t)
    if m:
        return "fn → " + shorten_type(m.group(1))

    # null or X
    m = re.match(r"^null or (.+)$", t)
    if m:
        return "?" + shorten_type(m.group(1))

    # list of X
    m = re.match(r"^list of (.+)$", t)
    if m:
        return "[" + shorten_type(m.group(1)) + "]"

    # attribute set of (submodule)
    if re.match(r"^attribute set of \(?submodule\)?$", t):
        return "{…}"

    # attribute set of X
    m = re.match(r"^attribute set of (.+)$", t)
    if m:
        return "{" + shorten_type(m.group(1)) + "}"

    # submodule (with or without parens)
    if t in ("submodule", "(submodule)"):
        return "{…}"

    # one of ...
    m = re.match(r'^one of (.+)$', t)
    if m:
        raw = m.group(1)
        # extract quoted strings
        vals = re.findall(r'"([^"]*)"', raw)
        if vals:
            if len(vals) > 5:
                return " | ".join(vals[:5]) + " | …"
            return " | ".join(vals)
        return raw

    # anything
    if t == "anything":
        return "any"

    # unsigned integers (various formats)
    m = re.match(r"^(\d+) bit unsigned integer.*$", t)
    if m:
        return "u" + m.group(1)
    if re.match(r"^unsigned integer.*$", t):
        return "uint"

    # signed integer
    if re.match(r"^signed integer.*$", t):
        return "int"

    # bounded integer
    m = re.match(r"^integer between (\S+) and (\S+).*$", t)
    if m:
        return f"int ({m.group(1)}..{m.group(2)})"

    # singular enum: value "X" (singular enum)
    m = re.match(r'^value "([^"]+)" \(singular enum\)$', t)
    if m:
        return json.dumps(m.group(1))

    simple = {
        "boolean": "bool",
        "string": "str",
        "integer": "int",
        "float": "float",
        "path": "path",
        "package": "pkg",
    }
    if t in simple:
        return simple[t]

    # X or Y (union)
    m = re.match(r'^(.+) or (.+)$', t)
    if m:
        return shorten_type(m.group(1)) + " | " + shorten_type(m.group(2))

    return t


def is_trivial_default(val):
    """Return True if the default value is trivial and should be omitted."""
    if val is None:
        return True
    if isinstance(val, bool) and val is False:
        return True
    if isinstance(val, str) and val == "":
        return True
    if isinstance(val, list) and len(val) == 0:
        return True
    if isinstance(val, dict) and len(val) == 0:
        return True
    return False


def format_default(val):
    """Format a default value for display."""
    if isinstance(val, bool):
        return "true" if val else "false"
    if isinstance(val, str):
        return json.dumps(val)
    if isinstance(val, (int, float)):
        return str(val)
    if isinstance(val, list):
        if len(val) == 0:
            return "[]"
        inner = ", ".join(format_default(v) for v in val)
        return "[" + inner + "]"
    if isinstance(val, dict):
        if len(val) == 0:
            return "{ }"
        return "{…}"
    if val is None:
        return "null"
    return str(val)


def clean_description(desc):
    """Extract a short inline description from a NixOS option description."""
    if not desc:
        return ""
    # Suppress placeholder descriptions
    if "this option has no description" in str(desc).lower():
        return ""
    # Strip XML/docbook tags
    text = re.sub(r"<[^>]+>", "", str(desc))
    # Strip markdown links but keep text
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    # Collapse whitespace
    text = re.sub(r"\s+", " ", text).strip()
    # Trim trailing period
    text = text.rstrip(".")
    # Take first sentence only
    m = re.match(r"^(.+?)[.!]\s", text)
    if m:
        text = m.group(1)
    # Strip "Whether to enable" prefix (redundant on absorbed enable options)
    m2 = re.match(r"^[Ww]hether to enable\s+", text)
    if m2:
        text = text[m2.end():]
    # Lowercase first character if it starts uppercase (sentence style → label style)
    if text and text[0].isupper() and (len(text) < 2 or not text[1].isupper()):
        text = text[0].lower() + text[1:]
    # Cap length
    if len(text) > 80:
        text = text[:77] + "…"
    return text


def build_tree(options, prefix):
    """Build a nested dict tree from flat dot-path options."""
    root = {"_children": {}}

    for name, opt in sorted(options.items()):
        # Strip submodule placeholder prefix (e.g. "<name>.")
        clean = re.sub(r"^<[^>]+>\.", "", name)
        if not clean.startswith(prefix):
            continue
        path = clean[len(prefix):]
        parts = path.split(".")
        node = root
        for part in parts[:-1]:
            if part not in node["_children"]:
                node["_children"][part] = {"_children": {}}
            node = node["_children"][part]
        leaf_name = parts[-1]
        node["_children"][leaf_name] = {
            "_children": {},
            "_opt": opt,
        }
    return root


def absorb_enable(tree):
    """Recursively find enable options and promote them to branch metadata."""
    children = tree.get("_children", {})
    for name, child in list(children.items()):
        absorb_enable(child)
        cc = child.get("_children", {})
        if "enable" in cc:
            enable_node = cc["enable"]
            opt = enable_node.get("_opt")
            if opt:
                typ = opt.get("type", "")
                default = opt.get("default", {})
                default_val = default.get("text", None) if isinstance(default, dict) else default
                if "bool" in typ.lower() or typ == "boolean":
                    child["_enable"] = opt
                    del cc["enable"]


def render_type(opt):
    """Render the type string for an option."""
    return shorten_type(opt.get("type", ""))


def render_leaf(name, opt):
    """Render a single leaf option as HTML."""
    typ = render_type(opt)
    default = opt.get("default", {})
    default_text = None
    if isinstance(default, dict):
        val = default.get("text")
        if val is not None:
            # try to parse as JSON to check triviality
            try:
                parsed = json.loads(val)
                if not is_trivial_default(parsed):
                    default_text = format_default(parsed)
            except (json.JSONDecodeError, TypeError):
                if val and val not in ('""', "[ ]", "{ }", "null", "false", ""):
                    default_text = str(val)
    elif not is_trivial_default(default):
        default_text = format_default(default)

    esc = html.escape
    parts = [f'<span class="oname">{esc(name)}</span>']
    if typ:
        parts.append(f' : <span class="otype">{esc(typ)}</span>')
    if default_text:
        parts.append(f' = <span class="odef">{esc(default_text)}</span>')

    desc = clean_description(opt.get("description", ""))
    if desc:
        parts.append(f' <span class="odesc">— {esc(desc)}</span>')

    return f'<div class="leaf">{"".join(parts)}</div>'


def render_tree(tree, depth=0):
    """Recursively render the tree as HTML."""
    children = tree.get("_children", {})
    if not children:
        return ""

    # Separate branches and leaves
    branches = []
    leaves = []
    for name, child in sorted(children.items()):
        cc = child.get("_children", {})
        has_opt = "_opt" in child
        has_children = bool(cc)
        if has_children:
            branches.append((name, child))
        elif has_opt:
            leaves.append((name, child))
        else:
            # empty branch (shouldn't happen, but handle gracefully)
            branches.append((name, child))

    lines = []
    for name, child in branches:
        enable = child.get("_enable")
        desc = ""
        if enable:
            desc = clean_description(enable.get("description", ""))

        esc = html.escape
        summary_parts = [esc(name)]
        if desc:
            summary_parts.append(f' <span class="odesc">— {esc(desc)}</span>')

        inner = render_tree(child, depth + 1)
        # Also render the branch's own _opt if it has one (rare: submodule with both value and children)
        own_opt = child.get("_opt")
        own_html = ""
        if own_opt:
            own_html = render_leaf(name, own_opt)

        lines.append(
            f'<details><summary>{"".join(summary_parts)}</summary>'
            f'<div class="branch">{own_html}{inner}</div></details>'
        )

    for name, child in leaves:
        lines.append(render_leaf(name, child["_opt"]))

    return "\n".join(lines)


PAGE_TEMPLATE = """\
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title} — psyclyx</title>
<style>
body {{
  font-family: system-ui, sans-serif;
  max-width: 64em;
  margin: 2em auto;
  padding: 0 1em;
  line-height: 1.5;
  color: #1a1a1a;
}}
nav {{ margin-bottom: 2em; }}
h1 {{ border-bottom: 2px solid #e0e0e0; padding-bottom: .3em; }}
a {{ color: #0057b7; }}
.tree {{
  font-family: ui-monospace, "Cascadia Code", "Source Code Pro", Menlo, Consolas, monospace;
  font-size: 0.9em;
  line-height: 1.7;
}}
.tree details {{
  margin: 0;
}}
.tree summary {{
  cursor: pointer;
  list-style: none;
  padding: 1px 0;
}}
.tree summary::-webkit-details-marker {{ display: none; }}
.tree summary::before {{
  content: "\\25b8\\00a0";
  color: #888;
}}
.tree details[open] > summary::before {{
  content: "\\25be\\00a0";
}}
.tree .branch {{
  padding-left: 1.5em;
}}
.tree .leaf {{
  padding: 1px 0;
}}
.oname {{ color: #1a1a1a; }}
.otype {{ color: #6a6a6a; }}
.odef {{ color: #999; }}
.odesc {{ color: #888; font-style: italic; }}
</style>
</head>
<body>
<nav><a href="index.html">&larr; index</a></nav>
<h1>{title} options</h1>
<div class="tree">
{tree}
</div>
</body>
</html>
"""


def main():
    parser = argparse.ArgumentParser(description="Render NixOS options.json to HTML tree")
    parser.add_argument("--title", required=True, help="Page title (e.g. NixOS, Home, Darwin)")
    parser.add_argument("--prefix", required=True, help="Option prefix to strip (e.g. psyclyx.nixos.)")
    parser.add_argument("infile", nargs="?", default=None, help="Input options.json (default: stdin)")
    args = parser.parse_args()

    if args.infile:
        with open(args.infile) as f:
            data = json.load(f)
    else:
        data = json.load(sys.stdin)

    tree = build_tree(data, args.prefix)
    absorb_enable(tree)
    tree_html = render_tree(tree)
    print(PAGE_TEMPLATE.format(title=html.escape(args.title), tree=tree_html))


if __name__ == "__main__":
    main()
