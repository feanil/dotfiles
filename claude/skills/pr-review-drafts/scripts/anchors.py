#!/usr/bin/env python3
"""List every commentable anchor in a PR diff, as line + side.

Usage: anchors.py OWNER/REPO N [path-substring]
"""
import json, re, subprocess, sys

repo, num = sys.argv[1], sys.argv[2]
want = sys.argv[3] if len(sys.argv) > 3 else ""
files = json.loads(subprocess.run(
    ["gh", "api", f"repos/{repo}/pulls/{num}/files", "--paginate"],
    capture_output=True, text=True, check=True).stdout)

for f in files:
    if want not in f["filename"] or not f.get("patch"):
        continue
    print(f"\n=== {f['filename']}  ({f['status']})")
    old = new = 0
    for raw in f["patch"].split("\n"):
        m = re.match(r"@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@", raw)
        if m:
            old, new = int(m.group(1)), int(m.group(2))
            continue
        if raw.startswith("-"):
            print(f"  line={old:<5} side=LEFT   {raw[:72]}")
            old += 1
        elif raw.startswith("+"):
            print(f"  line={new:<5} side=RIGHT  {raw[:72]}")
            new += 1
        else:
            print(f"  line={new:<5} side=RIGHT  {raw[:72]}")
            old += 1; new += 1
