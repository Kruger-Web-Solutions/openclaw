#!/bin/bash
TOKEN="rsqwYSsihAZJoRuTbvUAfkmgnCYcnhboZYbBEWaMNHFglNdcHVTYeGpjQkgwqTrb"
BASE="http://localhost:3004/api"

echo "=== Water containers ==="
curl -s -H "x-api-key: $TOKEN" "$BASE/measurements/water-intake/containers" 2>/dev/null
echo ""

echo "=== Water containers route ==="
curl -s -H "x-api-key: $TOKEN" "$BASE/water-containers" 2>/dev/null
echo ""

echo "=== Food entry schema ==="
docker exec sparky-sparkyfitness-server-1 \
  cat /app/SparkyFitnessServer/schemas/foodEntrySchemas.ts 2>/dev/null | head -60
