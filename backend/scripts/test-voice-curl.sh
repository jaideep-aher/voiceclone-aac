#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://127.0.0.1:3000}"
AUDIO="${AUDIO:-$(dirname "$0")/test-clone-15s.wav}"

echo "=== GET /api/voice/status (no auth — expect 401) ==="
curl -sS -i "$BASE_URL/api/voice/status" | head -20
echo

if [[ -z "${TOKEN:-}" ]]; then
  echo "Set TOKEN to a Supabase JWT to run authenticated voice tests."
  echo "Example: TOKEN=\$(curl -s ... signup ... | jq -r .access_token)"
  exit 0
fi

echo "=== GET /api/voice/status ==="
curl -sS -i "$BASE_URL/api/voice/status" -H "Authorization: Bearer $TOKEN" | head -25
echo

if [[ -f "$AUDIO" ]]; then
  echo "=== POST /api/voice/clone (multipart) ==="
  curl -sS -i -X POST "$BASE_URL/api/voice/clone" \
    -H "Authorization: Bearer $TOKEN" \
    -F "file=@${AUDIO};type=audio/wav" | head -40
  echo
else
  echo "Skip clone: generate audio with: node scripts/generate-test-audio.mjs"
fi

echo "=== POST /api/voice/synthesize (binary body) ==="
curl -sS -i -X POST "$BASE_URL/api/voice/synthesize" \
  -H "Authorization: Bearer $TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{"text":"Hello, this is a test of my cloned voice."}' \
  --output /tmp/vc-tts.mp3 | head -30
echo "Saved MPEG (if success) to /tmp/vc-tts.mp3 ($(wc -c </tmp/vc-tts.mp3 2>/dev/null || echo 0) bytes)"
echo

echo "=== DELETE /api/voice/clone (optional — removes ElevenLabs voice) ==="
echo "Uncomment to run: curl -X DELETE ..."
