#!/bin/bash
TOKEN=$(cat ~/.openclaw/secrets/sparky-token 2>/dev/null)
if [ -z "$TOKEN" ]; then echo "ERROR: ~/.openclaw/secrets/sparky-token missing"; exit 1; fi
BASE="http://localhost:3004/api"

echo "=== Get primary water container ==="
curl -s -H "x-api-key: $TOKEN" "$BASE/water-containers/primary" 2>/dev/null
echo ""

echo "=== Food entry DB schema (what columns exist) ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -A 40 "createFoodEntry" /app/SparkyFitnessServer/repositories/foodEntryRepository.js 2>/dev/null | head -50

echo "=== foodSchemas.ts ==="
docker exec sparky-sparkyfitness-server-1 \
  cat /app/SparkyFitnessServer/schemas/foodSchemas.ts 2>/dev/null | head -80
