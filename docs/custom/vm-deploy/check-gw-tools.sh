#!/bin/bash
GW_TOKEN=$(python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.openclaw/openclaw.json'))); print(d.get('token',''))" 2>/dev/null)
if [ -z "$GW_TOKEN" ]; then echo "ERROR: Could not read gateway token"; exit 1; fi
GW="http://localhost:18789"

echo "=== Gateway available tools ==="
curl -s -H "Authorization: Bearer $GW_TOKEN" "$GW/tools" 2>/dev/null | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
tools = data if isinstance(data, list) else data.get('tools', data.get('results', []))
if isinstance(tools, list):
    for t in sorted(tools, key=lambda x: x.get('name','') if isinstance(x,dict) else x):
        name = t.get('name', t) if isinstance(t, dict) else t
        print(f'  {name}')
else:
    print(json.dumps(data)[:500])
" 2>/dev/null

echo ""
echo "=== Gateway endpoints ==="
curl -s -H "Authorization: Bearer $GW_TOKEN" "$GW/" 2>/dev/null | head -c 300
echo ""
curl -s "$GW/health" 2>/dev/null | head -c 200
