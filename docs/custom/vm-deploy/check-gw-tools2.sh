#!/bin/bash
GW_TOKEN="2aa6a25578011d76b4663f1e01b18f28f1db4a5aa2b0050b"
GW="http://localhost:18789"

# Try different gateway tool listing endpoints
echo "=== Try /api/tools ==="
curl -s -H "Authorization: Bearer $GW_TOKEN" "$GW/api/tools" 2>/dev/null | head -c 500
echo ""

echo "=== Try POST invoke with 'list_tools' ==="
curl -s -X POST -H "Authorization: Bearer $GW_TOKEN" -H "Content-Type: application/json" \
  -d '{"tool":"list_tools","args":{}}' "$GW/tools/invoke" 2>/dev/null | head -c 500
echo ""

echo "=== Try invoke habitica to see its response format ==="
curl -s -X POST -H "Authorization: Bearer $GW_TOKEN" -H "Content-Type: application/json" \
  -d '{"tool":"habitica","args":{"action":"dashboard"}}' "$GW/tools/invoke" 2>/dev/null | head -c 500
echo ""

echo "=== Try sparky with different tool names ==="
for NAME in "sparky" "sparky_fitness" "sparkyFitness" "health" "sparky-fitness"; do
  CODE=$(curl -s -w "%{http_code}" -o /tmp/gw-resp.txt \
    -X POST -H "Authorization: Bearer $GW_TOKEN" -H "Content-Type: application/json" \
    -d "{\"tool\":\"$NAME\",\"args\":{\"action\":\"summary\"}}" "$GW/tools/invoke")
  RESP=$(cat /tmp/gw-resp.txt | head -c 100)
  echo "  $NAME → HTTP $CODE: $RESP"
done
