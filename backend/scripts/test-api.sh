#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:3000}"
EMAIL="${TEST_EMAIL:-voiceclone-test-$(date +%s)@example.com}"
PASSWORD="${TEST_PASSWORD:-testpass123456}"
DISPLAY_NAME="${TEST_DISPLAY_NAME:-Test User}"

echo "=== GET /health ==="
curl -sS -D - "$BASE_URL/health" -o /tmp/vc-health.json
echo
cat /tmp/vc-health.json
echo -e "\n"

echo "=== POST /api/auth/signup ==="
SIGNUP=$(curl -sS -X POST "$BASE_URL/api/auth/signup" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"display_name\":\"$DISPLAY_NAME\"}")
echo "$SIGNUP" | head -c 2000
echo -e "\n"

TOKEN=$(echo "$SIGNUP" | node -e "try{console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).access_token||'')}catch(e){}" 2>/dev/null || true)
if [[ -z "${TOKEN:-}" ]]; then
  echo "No access_token from signup — set SUPABASE_* in .env and apply DB migration, then re-run."
  exit 0
fi

echo "=== POST /api/auth/login ==="
curl -sS -X POST "$BASE_URL/api/auth/login" \
  -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" | head -c 1500
echo -e "\n\n"

echo "=== GET /api/profile ==="
curl -sS "$BASE_URL/api/profile" -H "Authorization: Bearer $TOKEN"
echo -e "\n\n"

echo "=== POST /api/phrases ==="
CREATE=$(curl -sS -X POST "$BASE_URL/api/phrases" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"text":"Can you pass the water?","category":"daily","is_quick_phrase":true}')
echo "$CREATE"
PHRASE_ID=$(echo "$CREATE" | node -e "try{console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).id||'')}catch(e){}" 2>/dev/null || true)
echo -e "\n"

echo "=== GET /api/phrases?category=daily ==="
curl -sS "$BASE_URL/api/phrases?category=daily" -H "Authorization: Bearer $TOKEN"
echo -e "\n\n"

if [[ -n "${PHRASE_ID:-}" ]]; then
  echo "=== PUT /api/phrases/:id ==="
  curl -sS -X PUT "$BASE_URL/api/phrases/$PHRASE_ID" \
    -H "Authorization: Bearer $TOKEN" \
    -H 'Content-Type: application/json' \
    -d '{"text":"Can you pass the water please?","category":"daily","is_quick_phrase":true}'
  echo -e "\n\n"

  echo "=== DELETE /api/phrases/:id ==="
  curl -sS -w "\nHTTP %{http_code}\n" -X DELETE "$BASE_URL/api/phrases/$PHRASE_ID" \
    -H "Authorization: Bearer $TOKEN"
  echo -e "\n"
fi

echo "=== POST /api/auth/apple (expect 401 without real id_token) ==="
curl -sS -X POST "$BASE_URL/api/auth/apple" \
  -H 'Content-Type: application/json' \
  -d '{"id_token":"invalid.test.token"}' | head -c 800
echo -e "\n"

echo "Done."
