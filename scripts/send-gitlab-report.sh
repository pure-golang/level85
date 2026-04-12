#!/bin/bash
set -euo pipefail

if [ -z "$REPORTER_API_TOKEN" ]; then
  echo "Ошибка: REPORTER_API_TOKEN не задан" >&2
  exit 1
fi

REPORT="$1"
if [ -z "$REPORT" ]; then
  echo "Ошибка: REPORT не задан" >&2
  exit 1
fi
HTTP_BODY=$(mktemp)
HTTP_CODE=$(curl -s --max-time 300 -X POST \
  -H "Authorization: Bearer ${REPORTER_API_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg body "$REPORT" '{"body": $body}')" \
  --write-out "%{http_code}" \
  --output "$HTTP_BODY" \
  "${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/merge_requests/${CI_MERGE_REQUEST_IID}/notes") || { echo "Ошибка: curl не смог подключиться (код: $?)" >&2; rm -f "$HTTP_BODY"; exit 1; }

RESPONSE=$(cat "$HTTP_BODY")
rm -f "$HTTP_BODY"
echo "[debug] HTTP $HTTP_CODE" >&2

if [ "$HTTP_CODE" -ne 201 ]; then
  echo "Ошибка: GitLab API вернул HTTP $HTTP_CODE" >&2
  exit 1
fi
NOTE_ID=$(echo "$RESPONSE" | jq -r '.id')
echo "note_${NOTE_ID}"
