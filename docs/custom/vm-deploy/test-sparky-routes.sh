#!/bin/bash
echo "=== Water intake POST body ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -A 15 "router.post.*water-intake" /app/SparkyFitnessServer/routes/measurementRoutes.js 2>/dev/null | head -20

echo "=== Check-in POST body ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -A 15 "router.post.*check-in" /app/SparkyFitnessServer/routes/measurementRoutes.js 2>/dev/null | head -30

echo "=== Food entry POST body ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -A 15 "router.post" /app/SparkyFitnessServer/routes/foodEntryRoutes.js 2>/dev/null | head -30
