#!/bin/bash
python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.openclaw/openclaw.json")
with open(path) as f:
    d = json.load(f)
# Find token anywhere
def find_token(obj, depth=0):
    if depth > 4: return
    if isinstance(obj, dict):
        for k, v in obj.items():
            if 'token' in k.lower() and isinstance(v, str) and len(v) > 20:
                print(f"  {k}: {v[:50]}")
            find_token(v, depth+1)
find_token(d)
PYEOF
