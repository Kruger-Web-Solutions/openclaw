#!/bin/bash
TOKEN=$(cat ~/.openclaw/secrets/sparky-token 2>/dev/null)
if [ -z "$TOKEN" ]; then echo "ERROR: ~/.openclaw/secrets/sparky-token missing"; exit 1; fi
BASE="http://localhost:3004/api"
TODAY=$(date +%Y-%m-%d)

echo "=== Step 1: Create test food (flat) ==="
FOOD_RESP=$(curl -s \
  -H "x-api-key: $TOKEN" -H "Content-Type: application/json" \
  -d '{"name":"TEST_E2E_FOOD","is_custom":true,"serving_size":100,"serving_unit":"g","calories":165,"protein":31,"carbs":0,"fat":3.6}' \
  "$BASE/foods")
echo "$FOOD_RESP" | head -c 300
FOOD_ID=$(echo "$FOOD_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)
VARIANT_ID=$(echo "$FOOD_RESP" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('default_variant',{}).get('id',''))" 2>/dev/null)
echo ""
echo "Food ID: $FOOD_ID"
echo "Variant ID: $VARIANT_ID"

echo ""
echo "=== Step 2: Create food entry with variant_id and correct meal type ==="
ENTRY_RESP=$(curl -s -w "\nHTTP:%{http_code}" \
  -H "x-api-key: $TOKEN" -H "Content-Type: application/json" \
  -d "{\"food_id\":\"$FOOD_ID\",\"variant_id\":\"$VARIANT_ID\",\"entry_date\":\"$TODAY\",\"meal_type\":\"snacks\",\"quantity\":100,\"unit\":\"g\"}" \
  "$BASE/food-entries")
ENTRY_CODE=$(echo "$ENTRY_RESP" | grep -o 'HTTP:[0-9]*' | grep -o '[0-9]*')
ENTRY_BODY=$(echo "$ENTRY_RESP" | sed 's/HTTP:[0-9]*$//')
echo "HTTP $ENTRY_CODE"
echo "$ENTRY_BODY" | head -c 400
ENTRY_ID=$(echo "$ENTRY_BODY" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null)

echo ""
echo "=== Step 3: Verify in diary ==="
curl -s -H "x-api-key: $TOKEN" "$BASE/food-entries?selectedDate=$TODAY" | \
  python3 -c "
import sys,json
items = json.load(sys.stdin)
print(f'Total diary entries: {len(items)}')
for item in items:
    print(f'  {item.get(\"food_name\",\"?\")} | cal={item.get(\"calories\",\"?\")} | meal={item.get(\"meal_type\",\"?\")}')
" 2>/dev/null

echo ""
echo "=== Step 4: Cleanup ==="
if [ -n "$ENTRY_ID" ]; then
  R=$(curl -s -w " HTTP:%{http_code}" -X DELETE -H "x-api-key: $TOKEN" "$BASE/food-entries/$ENTRY_ID")
  echo "Delete entry: $R"
fi
if [ -n "$FOOD_ID" ]; then
  R=$(curl -s -w " HTTP:%{http_code}" -X DELETE -H "x-api-key: $TOKEN" "$BASE/foods/$FOOD_ID")
  echo "Delete food: $R"
fi
