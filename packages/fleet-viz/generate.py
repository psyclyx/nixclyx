"""Generate fleet visualization from egregore entity JSON.

Produces:
- index.html: interactive fleet dashboard
- topology.dot + topology.svg: network topology graph
- exporters.dot + exporters.svg: host × exporter matrix
"""

import json
import sys
import os
from pathlib import Path


def load_fleet(path):
    with open(path) as f:
        return json.load(f)


def entities_of_type(data, type_name):
    return {k: v for k, v in data.get('entities', {}).items()
            if v.get('type') == type_name}


def generate_topology_dot(data):
    """Generate a Graphviz DOT graph of the network topology."""
    lines = ['digraph fleet {']
    lines.append('  rankdir=LR;')
    lines.append('  node [shape=box, style=filled, fontname="monospace"];')
    lines.append('  edge [fontname="monospace", fontsize=10];')
    lines.append('')

    networks = entities_of_type(data, 'network')
    hosts = entities_of_type(data, 'host')
    ha_groups = entities_of_type(data, 'ha-group')

    # Network nodes
    for net_name, net in networks.items():
        nd = net.get('network', {})
        ipv4 = nd.get('ipv4', '')
        vlan = nd.get('vlan', '')
        label = f"{net_name}\\nVLAN {vlan}\\n{ipv4}" if vlan else f"{net_name}\\n{ipv4}"
        lines.append(f'  net_{net_name} [label="{label}", shape=ellipse, '
                      f'style=filled, fillcolor="#e8f4f8"];')

    lines.append('')

    # Host nodes
    for host_name, host in hosts.items():
        hd = host.get('host', {})
        roles = ', '.join(hd.get('roles', []))
        addrs = []
        for net_name, addr in hd.get('addresses', {}).items():
            ipv4 = addr.get('ipv4', '')
            if ipv4:
                addrs.append(f"{net_name}: {ipv4}")
        addr_str = '\\n'.join(addrs)
        label = f"{host_name}\\n{roles}"
        if addr_str:
            label += f"\\n{addr_str}"

        color = '#d4edda' if 'server' in hd.get('roles', []) else '#fff3cd'
        if 'router' in hd.get('roles', []):
            color = '#f8d7da'
        elif 'workstation' in hd.get('roles', []):
            color = '#fff3cd'
        elif 'mobile' in hd.get('roles', []):
            color = '#e2e3e5'

        lines.append(f'  host_{host_name.replace("-", "_")} '
                      f'[label="{label}", fillcolor="{color}"];')

    lines.append('')

    # Host → Network edges
    for host_name, host in hosts.items():
        hd = host.get('host', {})
        for net_name in hd.get('addresses', {}):
            if net_name in networks or net_name == 'vpn':
                h = host_name.replace('-', '_')
                lines.append(f'  host_{h} -> net_{net_name} '
                              f'[dir=none, color="#6c757d"];')

    lines.append('')

    # HA VIP nodes
    for group_name, group in ha_groups.items():
        gd = group.get('ha-group', {})
        vip = gd.get('vip', {})
        ipv4 = vip.get('ipv4', '') if vip else ''
        services = ', '.join(gd.get('services', {}).keys())
        label = f"VIP: {group_name}\\n{ipv4}\\n{services}"
        lines.append(f'  vip_{group_name} [label="{label}", shape=diamond, '
                      f'style=filled, fillcolor="#d1ecf1"];')
        net = gd.get('network', '')
        if net:
            lines.append(f'  vip_{group_name} -> net_{net} '
                          f'[dir=none, style=dashed, color="#17a2b8"];')

    lines.append('}')
    return '\n'.join(lines)


def generate_service_matrix(data):
    """Generate an HTML table of hosts × exporters."""
    hosts = entities_of_type(data, 'host')
    all_exporters = set()
    for host in hosts.values():
        all_exporters.update(host.get('host', {}).get('exporters', {}).keys())
    all_exporters = sorted(all_exporters)

    rows = []
    for host_name in sorted(hosts.keys()):
        host_exporters = hosts[host_name].get('host', {}).get('exporters', {})
        cells = []
        for exp in all_exporters:
            if exp in host_exporters:
                port = host_exporters[exp].get('port', '')
                cells.append(f'<td class="active" title="{exp}:{port}">{port}</td>')
            else:
                cells.append('<td class="inactive"></td>')
        rows.append(f'<tr><th>{host_name}</th>{"".join(cells)}</tr>')

    header = ''.join(f'<th class="rotate"><div>{s}</div></th>' for s in all_exporters)
    return f'''<table class="service-matrix">
<thead><tr><th></th>{header}</tr></thead>
<tbody>{"".join(rows)}</tbody>
</table>'''


def generate_html(data, service_matrix):
    """Generate the main dashboard HTML."""
    hosts = entities_of_type(data, 'host')
    networks = entities_of_type(data, 'network')
    ha_groups = entities_of_type(data, 'ha-group')
    overlay = {
        'subnet': data.get('overlay', {}).get('subnet', 'n/a'),
        'hub': data.get('overlay', {}).get('hub', 'n/a'),
    }

    host_count = len(hosts)
    net_count = len(networks)
    svc_count = sum(len(h.get('host', {}).get('exporters', {})) for h in hosts.values())

    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Fleet Dashboard</title>
<style>
  :root {{
    --bg: #1a1b26; --fg: #c0caf5; --border: #3b4261;
    --accent: #7aa2f7; --green: #9ece6a; --red: #f7768e;
    --yellow: #e0af68; --cyan: #7dcfff;
  }}
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{
    font-family: "Berkeley Mono", "JetBrains Mono", monospace;
    background: var(--bg); color: var(--fg);
    padding: 2rem; line-height: 1.6;
  }}
  h1 {{ color: var(--accent); margin-bottom: 0.5rem; }}
  h2 {{ color: var(--cyan); margin: 2rem 0 1rem; border-bottom: 1px solid var(--border); padding-bottom: 0.5rem; }}
  .stats {{
    display: flex; gap: 2rem; margin: 1rem 0 2rem;
  }}
  .stat {{
    background: #24283b; padding: 1rem 1.5rem; border-radius: 8px;
    border: 1px solid var(--border);
  }}
  .stat-value {{ font-size: 2rem; font-weight: bold; color: var(--green); }}
  .stat-label {{ font-size: 0.8rem; color: #565f89; text-transform: uppercase; }}
  .service-matrix {{
    border-collapse: collapse; margin: 1rem 0;
  }}
  .service-matrix th, .service-matrix td {{
    border: 1px solid var(--border); padding: 4px 8px;
    font-size: 0.75rem; text-align: center;
  }}
  .service-matrix th {{ background: #24283b; }}
  .service-matrix .active {{ background: #1a3a2a; color: var(--green); }}
  .service-matrix .inactive {{ background: #1a1b26; }}
  .rotate {{ writing-mode: vertical-lr; text-orientation: mixed; }}
  .topology-svg {{ max-width: 100%; margin: 1rem 0; }}
  .network-list, .ha-list {{
    display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
    gap: 1rem; margin: 1rem 0;
  }}
  .card {{
    background: #24283b; border: 1px solid var(--border);
    border-radius: 8px; padding: 1rem;
  }}
  .card h3 {{ color: var(--accent); margin-bottom: 0.5rem; }}
  .card .detail {{ color: #565f89; font-size: 0.85rem; }}
</style>
</head>
<body>
<h1>Fleet Dashboard</h1>
<div class="stats">
  <div class="stat"><div class="stat-value">{host_count}</div><div class="stat-label">Hosts</div></div>
  <div class="stat"><div class="stat-value">{net_count}</div><div class="stat-label">Networks</div></div>
  <div class="stat"><div class="stat-value">{svc_count}</div><div class="stat-label">Exporter Instances</div></div>
  <div class="stat"><div class="stat-value">{len(ha_groups)}</div><div class="stat-label">HA Groups</div></div>
</div>

<h2>Network Topology</h2>
<img class="topology-svg" src="topology.svg" alt="Network topology graph">

<h2>Networks</h2>
<div class="network-list">
{''.join(f"""<div class="card">
  <h3>{name}</h3>
  <div class="detail">VLAN {net.get('network', {}).get('vlan', 'n/a')} &mdash; {net.get('network', {}).get('ipv4', '')}</div>
</div>""" for name, net in sorted(networks.items()))}
</div>

<h2>HA Groups</h2>
<div class="ha-list">
{''.join(f"""<div class="card">
  <h3>{name}</h3>
  <div class="detail">VIP: {group.get('ha-group', {}).get('vip', {}).get('ipv4', 'n/a')}</div>
  <div class="detail">Members: {', '.join(group.get('ha-group', {}).get('members', []))}</div>
  <div class="detail">Services: {', '.join(group.get('ha-group', {}).get('services', {}).keys())}</div>
</div>""" for name, group in sorted(ha_groups.items()))}
</div>

<h2>Exporter Matrix</h2>
{service_matrix}

<h2>WireGuard Overlay</h2>
<div class="card">
  <div class="detail">Subnet: {overlay['subnet']}</div>
  <div class="detail">Hub: {overlay['hub']}</div>
</div>
</body>
</html>'''


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <fleet.json> <output-dir>", file=sys.stderr)
        sys.exit(1)

    fleet_path = sys.argv[1]
    out_dir = Path(sys.argv[2])

    data = load_fleet(fleet_path)

    # Generate topology DOT and render SVG
    dot = generate_topology_dot(data)
    dot_path = out_dir / 'topology.dot'
    dot_path.write_text(dot)
    os.system(f'dot -Tsvg {dot_path} -o {out_dir}/topology.svg')

    # Generate HTML
    service_matrix = generate_service_matrix(data)
    html = generate_html(data, service_matrix)
    (out_dir / 'index.html').write_text(html)


if __name__ == '__main__':
    main()
