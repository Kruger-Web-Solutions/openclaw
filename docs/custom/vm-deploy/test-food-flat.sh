#!/bin/bash
TOKEN="rsqwYSsihAZJoRuTbvUAfkmgnCYcnhboZYbBEWaMNHFglNdcHVTYeGpjQkgwqTrb"
BASE="http://localhost:3004/api"

echo "=== Test: flat food payload (matches food.js model) ==="
R=$(curl -s -w "\nHTTP:%{http_code}" \
  -H "x-api-key: $TOKEN" -H "Content-Type: application/json" \
  -d '{
    "name": "TEST_FLAT_CHICKEN",
    "is_custom": true,
    "serving_size": 100,
    "serving_unit": "g",
    "calories": 165,
    "protein": 31,
    "carbs": 0,
    "fat": 3.6
  }' \
  "$BASE/foods" 2>/dev/null)

CODE=$(echo "$R" | grep -o 'HTTP:[0-9]*' | grep -o '[0-9]*')
BODY=$(echo "$R" | sed 's/HTTP:[0-9]*$//')
echo "HTTP $CODE"
echo "$BODY" | head -c 400

FOOD_ID=$(echo "$BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)
if [ -n "$FOOD_ID" ] && [ "$CODE" = "200" -o "$CODE" = "201" ]; then
  echo ""
  echo "Food ID: $FOOD_ID"
  
  echo ""
  echo "=== Test: food entry with this food ==="
  TODAY=$(date +%Y-%m-%d)
  R2=$(curl -s -w "\nHTTP:%{http_code}" \
    -H "x-api-key: $TOKEN" -H "Content-Type: application/json" \
    -d "{\"food_id\":\"$FOOD_ID\",\"entry_date\":\"$TODAY\",\"meal_type\":\"snack\",\"quantity\":100,\"unit\":\"g\"}" \
    "$BASE/food-entries" 2>/dev/null)
  CODE2=$(echo "$R2" | grep -o 'HTTP:[0-9]*' | grep -o '[0-9]*')
  BODY2=$(echo "$R2" | sed 's/HTTP:[0-9]*$//')
  echo "HTTP $CODE2"
  echo "$BODY2" | head -c 300
  ENTRY_ID=$(echo "$BODY2" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)
  
  echo ""
  echo "=== Cleanup: delete entry, delete food ==="
  if [ -n "$ENTRY_ID" ]; then
    curl -s -w "\nHTTP:%{http_code}" -X DELETE \
      -H "x-api-key: $TOKEN" "$BASE/food-entries/$ENTRY_ID"
    echo ""
  fi
  curl -s -w "\nHTTP:%{http_code}" -X DELETE \
    -H "x-api-key: $TOKEN" "$BASE/foods/$FOOD_ID"
  echo ""
fi
