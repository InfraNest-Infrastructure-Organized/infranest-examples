#!/bin/sh
# Silence alerts while a deploy runs, and close the window when it is done — even if the deploy failed.
#
#   maintenance.sh open    prints the new window's id
#   maintenance.sh close   closes the window in WINDOW_ID
#
#   INFRANEST_TOKEN   a token with Monitoring → Write
#   INFRANEST_ORG     your organization's id
#   CHECK_IDS         the monitors to silence, comma-separated, e.g. 1201,1202   (open)
#   NAME              what the window is called (default: Deploy)                  (open)
#   MINUTES           how long at most (default 30): it closes by itself then      (open)
#   DEPLOY_ID         something unique per deploy, e.g. your CI's pipeline id: a retried step opens one window
#   WINDOW_ID         the window to close                                         (close)
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

: "${INFRANEST_ORG:?Set INFRANEST_ORG}"
ORG="/organizations/$INFRANEST_ORG"

in_minutes() {
  # GNU date (Linux, most CI) or BSD date (macOS).
  date -u -d "+$1 minutes" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v "+$1M" +%Y-%m-%dT%H:%M:%SZ
}

case "${1:-}" in
  open)
    : "${CHECK_IDS:?Set CHECK_IDS}"
    body=$(jq -n --arg name "${NAME:-Deploy}" --arg start "$(in_minutes 0)" --arg end "$(in_minutes "${MINUTES:-30}")" \
      --arg ids "$CHECK_IDS" \
      '{name: $name, starts_at: $start, ends_at: $end, suppress_alerts: true, check_ids: ($ids | split(",") | map(tonumber))}')
    infranest POST "$ORG/maintenance-windows" "$body" "deploy-${DEPLOY_ID:-$(date -u +%s)}" | jq -r .id
    ;;
  close)
    : "${WINDOW_ID:?Set WINDOW_ID}"
    infranest PATCH "$ORG/maintenance-windows/$WINDOW_ID/complete" > /dev/null
    echo "Maintenance window $WINDOW_ID closed; alerts are back on."
    ;;
  *)
    echo "Usage: maintenance.sh open|close" >&2
    exit 2
    ;;
esac
