#!/bin/bash
echo "=== ~/.openclaw/mcp-server.mjs (first 50 lines) ==="
head -50 ~/.openclaw/mcp-server.mjs 2>/dev/null

echo ""
echo "=== HABITICA env in openclaw.json ==="
python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.openclaw/openclaw.json")
with open(path) as f:
    d = json.load(f)
# Search all keys
def search(obj, path=""):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if "habitica" in str(k).lower():
                print(f"  KEY {path}.{k}: {str(v)[:100]}")
            search(v, f"{path}.{k}")
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            search(v, f"{path}[{i}]")
    elif isinstance(obj, str) and "habitica" in obj.lower() and len(obj) < 200:
        print(f"  VAL {path}: {obj[:100]}")
search(d)
PYEOF

echo ""
echo "=== openclaw tools config ==="
python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.openclaw/openclaw.json")
with open(path) as f:
    d = json.load(f)
tools = d.get('tools', {})
print(json.dumps(tools, indent=2)[:500])
PYEOF

echo ""
echo "=== Skills directory ==="
ls ~/.openclaw/workspace/skills/ 2>/dev/null | head -20
