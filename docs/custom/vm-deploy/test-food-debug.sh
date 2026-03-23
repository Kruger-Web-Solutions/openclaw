#!/bin/bash
TOKEN=$(cat ~/.openclaw/secrets/sparky-token 2>/dev/null)
if [ -z "$TOKEN" ]; then echo "ERROR: ~/.openclaw/secrets/sparky-token missing"; exit 1; fi
BASE="http://localhost:3004/api"

echo "=== Debug: food creation with different payload shapes ==="

# Test 1: Exactly matching NormalizedFoodSchema
echo ""
echo "--- Test 1: NormalizedFoodSchema exact match ---"
curl -s -w "\nHTTP:%{http_code}" \
  -H "x-api-key: $TOKEN" -H "Content-Type: application/json" \
  -d '{
    "name": "TEST_FOOD_DEBUG",
    "brand": null,
    "is_custom": true,
    "default_variant": {
      "serving_size": 100,
      "serving_unit": "g",
      "calories": 165,
      "protein": 31,
      "carbs": 0,
      "fat": 3.6,
      "is_default": true
    },
    "variants": []
  }' \
  "$BASE/foods" 2>/dev/null

echo ""
echo "--- Test 2: With integer serving_size, no brand field ---"
curl -s -w "\nHTTP:%{http_code}" \
  -H "x-api-key: $TOKEN" -H "Content-Type: application/json" \
  -d '{
    "name": "TEST_FOOD_DEBUG2",
    "is_custom": true,
    "default_variant": {
      "serving_size": 100,
      "serving_unit": "g",
      "calories": 165,
      "protein": 31.0,
      "carbs": 0.0,
      "fat": 3.6,
      "is_default": true
    }
  }' \
  "$BASE/foods" 2>/dev/null

echo ""
echo "=== Check what foodRepository.createFood expects ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -A 50 "createFood" /app/SparkyFitnessServer/repositories/foodRepository.js 2>/dev/null | head -60
