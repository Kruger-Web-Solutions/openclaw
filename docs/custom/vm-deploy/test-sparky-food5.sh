#!/bin/bash
TOKEN="rsqwYSsihAZJoRuTbvUAfkmgnCYcnhboZYbBEWaMNHFglNdcHVTYeGpjQkgwqTrb"

echo "=== foodIntegration routes ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -n "router\." /app/SparkyFitnessServer/routes/foodIntegrationRoutes.js 2>/dev/null | head -20

echo "=== foodCrud routes ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -n "router\." /app/SparkyFitnessServer/routes/foodCrudRoutes.js 2>/dev/null | head -20

echo "=== Search food by name ==="
curl -s -H "x-api-key: $TOKEN" \
  "http://localhost:3004/api/foods/search?name=chicken+breast&limit=2" 2>/dev/null | head -c 800
echo ""

echo "=== Search food with query param ==="
curl -s -H "x-api-key: $TOKEN" \
  "http://localhost:3004/api/foods?query=chicken&limit=2" 2>/dev/null | head -c 800
echo ""
