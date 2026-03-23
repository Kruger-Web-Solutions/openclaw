#!/bin/bash
echo "=== Checking Habitica config ==="
python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.openclaw/openclaw.json")
with open(path) as f:
    d = json.load(f)
for k, v in d.items():
    if "habitica" in k.lower() or "plugin" in k.lower():
        print(f"{k}: {v}")
PYEOF
echo "=== Checking for extensions/plugin config ==="
cat ~/.openclaw/openclaw.json | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('Top-level keys:', list(d.keys())[:20])
"
echo "=== Secrets folder ==="
ls ~/.openclaw/secrets/
