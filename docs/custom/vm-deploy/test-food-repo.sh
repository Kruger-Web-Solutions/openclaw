#!/bin/bash
echo "=== Check food repository SQL ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -r "INSERT.*food_variants\|food_variants.*INSERT" /app/SparkyFitnessServer/ 2>/dev/null | grep -v node_modules | head -5

echo "=== Check food service createFood ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -A 60 "async createFood\|createFood = async" /app/SparkyFitnessServer/services/foodService.js 2>/dev/null | head -70

echo "=== Check createFood in repository ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -n "createFood" /app/SparkyFitnessServer/repositories/foodRepository.js 2>/dev/null | head -10

echo "=== foodRepository file lines 1-80 ==="
docker exec sparky-sparkyfitness-server-1 \
  sed -n '1,80p' /app/SparkyFitnessServer/repositories/foodRepository.js 2>/dev/null
