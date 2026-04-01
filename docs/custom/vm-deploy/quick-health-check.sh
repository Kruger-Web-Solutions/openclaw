#!/usr/bin/env bash
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
echo "=== Quick Gateway Health Check ==="
curl -sf http://localhost:18789/health && echo " [OK] Health endpoint" || echo " [FAIL] Health endpoint"
echo ""
echo "=== Token check ==="
python3 -c "import json,os; d=json.load(open(os.path.expanduser('~/.openclaw/openclaw.json'))); print('token' in d or 'gateway' in d or 'auth' in d, list(d.keys())[:10])"
echo ""
echo "=== Channels status ==="
openclaw channels status 2>&1 | head -20
echo ""
echo "=== Plugin inventory ==="
openclaw channels status 2>&1 | grep -E "habitica|whatsapp|archive" || true
echo ""
echo "=== Cron count ==="
openclaw cron list 2>&1 | wc -l
echo ""
echo "=== Gateway logs (last 15 lines) ==="
openclaw logs --plain 2>&1 | tail -15 || journalctl --user -u openclaw-gateway -n 15 --no-pager 2>&1
