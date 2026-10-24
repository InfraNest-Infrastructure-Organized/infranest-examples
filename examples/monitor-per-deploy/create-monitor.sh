#!/bin/sh
# Make sure a new service is watched: create its monitor, once, from the pipeline that deploys it.
#
#   INFRANEST_TOKEN   a token with Monitoring → Write
#   INFRANEST_ORG     your organization's id
#   NAME              e.g. "API health"
#   TARGET            e.g. https://api.example.com/health
#   TYPE              http (default), port, ssl, dns, keyword, redirect, ping or api
#   INTERVAL          seconds between checks: 30, 60, 120, 300 (default), 600, 900, 1800 or 3600
set -eu

API="${INFRANEST_API:-https://api.infranest.io/api}"
: "${INFRANEST_TOKEN:?Set INFRANEST_TOKEN to an InfraNest API token}"

# infranest METHOD PATH [JSON BODY] [IDEMPOTENCY KEY]
# Calls the InfraNest API and prints the JSON answer. Exits non-zero, printing the error, on a refusal.
infranest() {
  if [ -n "${3:-}" ]; then
    curl -sS --fail-with-body -X "$1" "$API$2" \
      -H "Authorization: Bearer $INFRANEST_TOKEN" -H "Accept: application/json" \
      -H "Content-Type: application/json" ${4:+-H "Idempotency-Key: $4"} -d "$3"
  else
    curl -sS --fail-with-body -X "$1" "$API$2" \
      -H "Authorization: Bearer $INFRANEST_TOKEN" -H "Accept: application/json"
  fi
}

: "${INFRANEST_ORG:?Set INFRANEST_ORG}" "${NAME:?Set NAME}" "${TARGET:?Set TARGET}"
ORG="/organizations/$INFRANEST_ORG"

# Already watched? Then there is nothing to do.
existing=$(infranest GET "$ORG/monitoring-checks" | jq -r --arg t "$TARGET" '[(.data // .)[] | select(.target == $t)][0].id // empty')
if [ -n "$existing" ]; then
  echo "$existing"
  exit 0
fi

body=$(jq -n --arg name "$NAME" --arg target "$TARGET" --arg type "${TYPE:-http}" --argjson interval "${INTERVAL:-300}" \
  '{name: $name, type: $type, target: $target, interval_seconds: $interval}')
infranest POST "$ORG/monitoring-checks" "$body" "monitor-$TARGET" | jq -r .id
