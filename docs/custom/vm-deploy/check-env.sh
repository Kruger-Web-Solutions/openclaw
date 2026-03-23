#!/bin/bash
echo "=== OpenClaw env config ==="
openclaw config get env 2>/dev/null

echo "=== openclaw.json env section ==="
python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.openclaw/openclaw.json")
with open(path) as f:
    d = json.load(f)
env = d.get("env", {})
if env:
    for k, v in env.items():
        print(f"  {k}: {v}")
else:
    print("  (empty)")
PYEOF
