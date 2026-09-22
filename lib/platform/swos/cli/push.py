"""POST each section of a SwOS .swb to the switch.

SwOS ignores multipart backup uploads, so a restore is a per-section
POST. Usage: push.py <file.swb> <host> <user> <password>
"""
import re
import subprocess
import sys


def sections(data):
    out, i = [], 0
    while i < len(data):
        m = re.match(r"(\w+\.b):", data[i:])
        if not m:
            i += 1
            continue
        start = i + len(m.group(0))
        depth = 0
        for j, c in enumerate(data[start:]):
            if c in "{[":
                depth += 1
            elif c in "}]":
                depth -= 1
            if depth == 0:
                out.append((m.group(1), data[start : start + j + 1]))
                i = start + j + 2
                break
        else:
            break
    return out


def main():
    data = open(sys.argv[1]).read()
    host, user, password = sys.argv[2], sys.argv[3], sys.argv[4]

    failed = False
    for name, content in sections(data):
        r = subprocess.run(
            [
                "curl", "-sf", "--connect-timeout", "5", "--max-time", "10",
                "--digest", "-u", f"{user}:{password}",
                "-X", "POST", "-d", content, f"http://{host}/{name}",
            ],
            capture_output=True,
            timeout=15,
        )
        print(f'  {"ok" if r.returncode == 0 else "FAIL"}: {name}', file=sys.stderr)
        failed = failed or r.returncode != 0

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
