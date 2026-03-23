#!/bin/bash
TOKEN=$(cat ~/.openclaw/secrets/sparky-token 2>/dev/null)
if [ -z "$TOKEN" ]; then echo "ERROR: ~/.openclaw/secrets/sparky-token missing"; exit 1; fi
BASE="http://localhost:3004/api"

echo "=== foodCrudRoutes GET /56 and POST /192 ==="
docker exec sparky-sparkyfitness-server-1 \
  sed -n '50,230p' /app/SparkyFitnessServer/routes/foodCrudRoutes.js 2>/dev/null

echo "=== POST water-intake test ==="
curl -s -w "\nHTTP:%{http_code}" \
  -H "x-api-key: $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"entry_date\":\"2026-03-23\",\"change_drinks\":1,\"container_id\":null}" \
  "$BASE/measurements/water-intake"
echo ""
