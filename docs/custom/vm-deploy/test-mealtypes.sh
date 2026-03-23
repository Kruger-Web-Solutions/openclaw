#!/bin/bash
TOKEN=$(cat ~/.openclaw/secrets/sparky-token 2>/dev/null)
if [ -z "$TOKEN" ]; then echo "ERROR: ~/.openclaw/secrets/sparky-token missing"; exit 1; fi
echo "=== Get meal types ==="
curl -s -H "x-api-key: $TOKEN" "http://localhost:3004/api/meal-types" | python3 -c "
import sys, json
data = json.load(sys.stdin)
items = data if isinstance(data, list) else data.get('results', data)
if isinstance(items, list):
    for m in items:
        print(f'  id={m.get(\"id\")} name={m.get(\"name\")} sort={m.get(\"sort_order\")}')
else:
    print(data)
"

echo "=== foodEntry model - how meal_type is resolved ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -B2 -A 15 "Invalid meal type" /app/SparkyFitnessServer/models/foodEntry.js 2>/dev/null | head -30
