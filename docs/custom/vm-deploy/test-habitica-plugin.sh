#!/usr/bin/env bash
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

echo "=== Habitica plugin loaded? ==="
openclaw config get plugins 2>&1 | grep -i habitica || echo "(not in explicit config - checking auto-load)"

echo ""
echo "=== Gateway token path ==="
python3 - <<'PYEOF'
import json, os
d = json.load(open(os.path.expanduser('~/.openclaw/openclaw.json')))
def find_token(obj, path=''):
    if isinstance(obj, str) and len(obj) > 20 and 'token' in path.lower():
        print(f"  {path} = {obj[:12]}...")
    elif isinstance(obj, dict):
        for k, v in obj.items():
            find_token(v, f"{path}.{k}" if path else k)
find_token(d)
PYEOF

echo ""
echo "=== Habitica via openclaw CLI ==="
openclaw agent --local --message "Use the habitica tool: action=dashboard. Reply with just the character name and HP." 2>&1 | tail -10 || echo "[local agent run failed]"
