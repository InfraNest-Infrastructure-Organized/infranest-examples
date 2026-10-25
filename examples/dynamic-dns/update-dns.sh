#!/bin/sh
# Keep one A (or AAAA) record pointing at this machine's public address. Run it every few minutes from cron.
# Only a changed address is sent, so the zone's history shows real changes only.
#
#   INFRANEST_TOKEN   a token with DNS → Write
#   INFRANEST_ORG     your organization's id
#   ZONE_ID           the zone's id      (GET /organizations/{org}/dns-zones)
#   RECORD_ID         the record's id    (GET /organizations/{org}/dns-zones/{zone}/dns-records?type=A)
#   FAMILY            4 (default) or 6
#   ADDRESS           optional: use this address instead of looking it up (from your router, or for a test)
#   DRY_RUN           1 to only show what would change
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

: "${INFRANEST_ORG:?Set INFRANEST_ORG}" "${ZONE_ID:?Set ZONE_ID}" "${RECORD_ID:?Set RECORD_ID}"
RECORD="/organizations/$INFRANEST_ORG/dns-zones/$ZONE_ID/dns-records/$RECORD_ID"

if [ "${FAMILY:-4}" = "6" ]; then lookup=https://api64.ipify.org; else lookup=https://api.ipify.org; fi
current=${ADDRESS:-$(curl -fsS "$lookup")}
stored=$(infranest GET "$RECORD" | jq -r .value)

if [ "$current" = "$stored" ]; then
  exit 0
fi

body=$(jq -n --arg value "$current" '{value: $value, ttl: 300}')
if [ "${DRY_RUN:-0}" = "1" ]; then
  infranest PUT "$RECORD?dry_run=1" "$body" | jq '.changes'
else
  infranest PUT "$RECORD" "$body" > /dev/null
  echo "Updated from $stored to $current"
fi
