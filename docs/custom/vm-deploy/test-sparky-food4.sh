#!/bin/bash
TOKEN="rsqwYSsihAZJoRuTbvUAfkmgnCYcnhboZYbBEWaMNHFglNdcHVTYeGpjQkgwqTrb"

echo "=== Food search with name param ==="
curl -s -H "x-api-key: $TOKEN" \
  "http://localhost:3004/api/v2/foods?name=chicken+breast&limit=2" 2>/dev/null | head -c 800
echo ""

echo "=== All food routes ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -n "router\." /app/SparkyFitnessServer/routes/foodRoutes.js 2>/dev/null | head -20

echo "=== v2 food routes ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -n "router\." /app/SparkyFitnessServer/routes/v2/foodRoutes.js 2>/dev/null | head -20

echo "=== Food search params ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -A 10 "search\|query\|name" /app/SparkyFitnessServer/routes/foodRoutes.js 2>/dev/null | head -30
