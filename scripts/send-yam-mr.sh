#!/bin/bash
set -euo pipefail

NOTE="$1"
if [ -z "$NOTE" ]; then
  echo "Ошибка: NOTE не задан" >&2
  exit 1
fi
MR_URL="${CI_MERGE_REQUEST_PROJECT_URL}/-/merge_requests/${CI_MERGE_REQUEST_IID}#${NOTE}"
TEXT="[**${CI_PROJECT_NAME} (${CI_MERGE_REQUEST_SOURCE_BRANCH_NAME})** ${CI_MERGE_REQUEST_TITLE}](${MR_URL})"
HTTP_BODY=$(mktemp)
HTTP_CODE=$(curl -s --max-time 30 -X POST \
  -H "Authorization: OAuth ${YAM_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg chat_id "$YAM_CHAT_ID" --arg text "$TEXT" '{"chat_id": $chat_id, "text": $text, "disable_web_page_preview": true}')" \
  --write-out "%{http_code}" \
  --output "$HTTP_BODY" \
  https://botapi.messenger.yandex.net/bot/v1/messages/sendText/) || { echo "Ошибка: curl не смог подключиться к Yandex Messenger (код: $?)" >&2; rm -f "$HTTP_BODY"; exit 1; }

echo "[debug] HTTP $HTTP_CODE response: $(cat "$HTTP_BODY")" >&2
rm -f "$HTTP_BODY"

if [ "$HTTP_CODE" -ne 200 ]; then
  echo "Ошибка: Yandex Messenger API вернул HTTP $HTTP_CODE" >&2
  exit 1
fi
