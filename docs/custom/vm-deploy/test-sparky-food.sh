#!/bin/bash
TOKEN=$(cat ~/.openclaw/secrets/sparky-token 2>/dev/null)
if [ -z "$TOKEN" ]; then echo "ERROR: ~/.openclaw/secrets/sparky-token missing"; exit 1; fi
BASE="http://localhost:3004/api"

echo "=== waterContainerRoutes routes ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -n "router\." /app/SparkyFitnessServer/routes/waterContainerRoutes.js 2>/dev/null | head -20

echo "=== app.use for waterContainer ==="
docker exec sparky-sparkyfitness-server-1 \
  grep "waterContainer\|water-container" /app/SparkyFitnessServer/SparkyFitnessServer.js 2>/dev/null

echo "=== Food entry schema file ==="
docker exec sparky-sparkyfitness-server-1 \
  find /app/SparkyFitnessServer/schemas -name "*food*" 2>/dev/null

echo "=== Food entry body ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -A 30 "createFoodEntry" /app/SparkyFitnessServer/services/foodEntryService.js 2>/dev/null | head -40
