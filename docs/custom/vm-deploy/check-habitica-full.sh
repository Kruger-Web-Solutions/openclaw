#!/bin/bash
GW_TOKEN="2aa6a25578011d76b4663f1e01b18f28f1db4a5aa2b0050b"
GW="http://localhost:18789"

echo "=== Habitica: existing dailies ==="
curl -s -X POST \
  -H "Authorization: Bearer $GW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tool":"habitica","args":{"action":"dailies"}}' \
  "$GW/tools/invoke" | python3 -c "
import sys, json
resp = json.load(sys.stdin)
content = resp.get('result', {}).get('content', [{}])
text = content[0].get('text', '') if content else ''
try:
    data = json.loads(text)
    dailies = data.get('dailies', data) if isinstance(data, dict) else data
    if isinstance(dailies, list):
        print(f'Total dailies: {len(dailies)}')
        for d in dailies:
            due = '⚠ DUE' if not d.get('completed') else '✓ done'
            print(f'  [{due}] {d.get(\"text\",\"?\")} (streak={d.get(\"streak\",0)})')
    else:
        print(text[:1000])
except:
    print(text[:2000])
"

echo ""
echo "=== Habitica: existing habits ==="
curl -s -X POST \
  -H "Authorization: Bearer $GW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tool":"habitica","args":{"action":"habits"}}' \
  "$GW/tools/invoke" | python3 -c "
import sys, json
resp = json.load(sys.stdin)
content = resp.get('result', {}).get('content', [{}])
text = content[0].get('text', '') if content else ''
try:
    data = json.loads(text)
    habits = data.get('habits', data) if isinstance(data, dict) else data
    if isinstance(habits, list):
        print(f'Total habits: {len(habits)}')
        for h in habits:
            print(f'  + {h.get(\"text\",\"?\")} (value={round(h.get(\"value\",0),1)})')
    else:
        print(text[:1000])
except:
    print(text[:2000])
"

echo ""
echo "=== Habitica: todos ==="
curl -s -X POST \
  -H "Authorization: Bearer $GW_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"tool":"habitica","args":{"action":"todos"}}' \
  "$GW/tools/invoke" | python3 -c "
import sys, json
resp = json.load(sys.stdin)
content = resp.get('result', {}).get('content', [{}])
text = content[0].get('text', '') if content else ''
try:
    data = json.loads(text)
    todos = data.get('todos', data) if isinstance(data, dict) else data
    if isinstance(todos, list):
        print(f'Total todos: {len(todos)}')
        for t in todos[:10]:
            print(f'  • {t.get(\"text\",\"?\")}')
    else:
        print(text[:500])
except:
    print(text[:500])
"
