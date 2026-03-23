#!/bin/bash
echo "=== Check .cursor/mcp.json ==="
cat ~/.openclaw/workspace/.cursor/mcp.json 2>/dev/null || cat ~/.cursor/mcp.json 2>/dev/null || echo "(not found)"

echo ""
echo "=== Check openclaw.json mcp config ==="
python3 - << 'PYEOF'
import json, os
path = os.path.expanduser("~/.openclaw/openclaw.json")
with open(path) as f:
    d = json.load(f)
mcp = d.get('mcp', d.get('mcpServers', d.get('mcpClients', {})))
print("mcp:", json.dumps(mcp, indent=2) if mcp else "(not found)")

# Check skills
skills = d.get('skills', {})
print("skills:", json.dumps(skills, indent=2)[:200] if skills else "(not found)")

# Check agents tools
agents = d.get('agents', {})
print("agents tools:", json.dumps({k: v.get('tools') for k, v in agents.items() if 'tools' in v}, indent=2)[:300] if agents else "(not found)")
PYEOF

echo ""
echo "=== Check workspace docs for agent tool config ==="
ls ~/.openclaw/workspace/docs/ 2>/dev/null | head -20

echo ""
echo "=== Available tools shown in habitica response ==="
# The fact habitica works - let's see what tool categories exist
curl -s -X POST -H "Authorization: Bearer 2aa6a25578011d76b4663f1e01b18f28f1db4a5aa2b0050b" \
  -H "Content-Type: application/json" \
  -d '{"tool":"message","args":{"action":"send","channel":"whatsapp","to":"+27711304241","message":"[INTERNAL TEST] ignore"}}' \
  "http://localhost:18789/tools/invoke" 2>/dev/null | head -c 200
