#!/bin/bash
echo "=== Check-in schema ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -r "UpsertCheckInBodySchema" /app/SparkyFitnessServer/ 2>/dev/null | grep -v "node_modules" | grep "\.safeParse\|= z\.\|shape\|weight\|entry_date" | head -20

echo "=== Check the schema file ==="
docker exec sparky-sparkyfitness-server-1 \
  find /app/SparkyFitnessServer -name "*.js" -exec grep -l "UpsertCheckInBodySchema" {} \; 2>/dev/null | grep -v node_modules

echo "=== Water schema ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -r "UpsertWaterIntakeBodySchema" /app/SparkyFitnessServer/ 2>/dev/null | grep -v "node_modules" | grep "\.safeParse\|= z\.\|shape\|amount\|entry_date" | head -20

echo "=== Food entry service createFoodEntry ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -r "createFoodEntry" /app/SparkyFitnessServer/services/ 2>/dev/null | grep -v "node_modules" | head -5
