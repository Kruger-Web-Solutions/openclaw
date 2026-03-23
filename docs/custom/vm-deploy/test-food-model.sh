#!/bin/bash
echo "=== food model INSERT ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -A 30 "INSERT INTO food_variants" /app/SparkyFitnessServer/models/food.js 2>/dev/null | head -40

echo "=== food.js - createFood function signature ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -n "createFood\|static.*create\|async create" /app/SparkyFitnessServer/models/food.js 2>/dev/null | head -10

echo "=== food.js - first 60 lines ==="
docker exec sparky-sparkyfitness-server-1 \
  sed -n '1,60p' /app/SparkyFitnessServer/models/food.js 2>/dev/null
