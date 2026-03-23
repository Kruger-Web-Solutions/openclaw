#!/bin/bash
echo "=== Food entry repository insert columns ==="
docker exec sparky-sparkyfitness-server-1 \
  grep -A 30 "INSERT.*food_entries\|INSERT.*food_entry" /app/SparkyFitnessServer/repositories/foodEntryRepository.js 2>/dev/null | head -50

echo "=== Food search endpoint test ==="
TOKEN=$(cat ~/.openclaw/secrets/sparky-token 2>/dev/null)
if [ -z "$TOKEN" ]; then echo "ERROR: ~/.openclaw/secrets/sparky-token missing"; exit 1; fi
curl -s -H "x-api-key: $TOKEN" \
  "http://localhost:3004/api/foods/search?query=chicken+breast&limit=2" 2>/dev/null | head -c 800

echo ""
echo "=== POST food entry (custom - no food_id) ==="
curl -s -w "\nHTTP:%{http_code}" \
  -H "x-api-key: $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "entry_date": "2026-03-23",
    "meal_type": "lunch",
    "calories": 300,
    "protein": 25,
    "carbs": 10,
    "fat": 15,
    "quantity": 1,
    "unit": "serving",
    "food_name": "Test chicken"
  }' \
  "http://localhost:3004/api/food-entries" 2>/dev/null
