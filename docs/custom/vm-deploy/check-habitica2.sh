#!/bin/bash
echo "=== Habitica plugin config ==="
cat ~/.openclaw/openclaw.json | python3 -c "
import sys, json
d = json.load(sys.stdin)
plugins = d.get('plugins', {})
print(json.dumps(plugins, indent=2))
"
echo "=== Env vars with habitica ==="
cat ~/.openclaw/openclaw.json | python3 -c "
import sys, json
d = json.load(sys.stdin)
env = d.get('env', {})
for k, v in env.items():
    if 'habitica' in k.lower():
        print(f'{k}: {v}')
"
echo "=== Gateway env ==="
cat ~/.openclaw/openclaw.json | python3 -c "
import sys, json
d = json.load(sys.stdin)
gw = d.get('gateway', {})
for k, v in gw.items():
    if 'habitica' in str(k).lower() or 'habitica' in str(v).lower():
        print(f'{k}: {v}')
"
echo "=== openclaw config get habitica ==="
openclaw config get plugins.entries.habitica 2>/dev/null
