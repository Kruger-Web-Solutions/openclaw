#!/usr/bin/env bash
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/bin:/bin:$PATH"

echo "=== Plugin check ==="
openclaw gateway status --probe 2>&1 | head -30 || true

echo ""
echo "=== Habitica tool invoke test ==="
TOKEN=$(python3 -c "
import json, os
d = json.load(open(os.path.expanduser('~/.openclaw/openclaw.json')))
# try various token paths
for path in [d.get('token'), d.get('gateway', {}).get('token'), d.get('gateway', {}).get('auth', {}).get('token')]:
    if path:
        print(path)
        break
")
echo "Token found: ${TOKEN:0:8}..."

curl -sf -X POST http://localhost:18789/tools/invoke \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"tool":"habitica","params":{"action":"dashboard"}}' 2>&1 | python3 -c "
import json,sys
d=json.loads(sys.stdin.read())
print('habitica tool response keys:', list(d.keys()) if isinstance(d, dict) else type(d).__name__)
" || echo "[habitica invoke failed - may need gateway token check]"

echo ""
echo "=== WhatsApp archive check ==="
test -f ~/.openclaw/whatsapp/archive.sqlite && echo "archive.sqlite EXISTS" || echo "archive.sqlite not yet created (expected if archive disabled or no messages yet)"

echo ""
echo "=== Recent gateway errors ==="
journalctl --user -u openclaw-gateway --since "10 minutes ago" --no-pager 2>&1 | grep -iE "error|warn|fail" | head -15 || echo "(no errors in last 10 min)"
