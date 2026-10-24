#!/bin/sh
# A first run against your sandbox: reset it, change a DNS record and put it back.
# Nothing here touches a real provider — the sandbox never reaches out.
#
#   INFRANEST_TOKEN   a test token made in your sandbox (it starts with in_test_ after the id)
#   INFRANEST_ORG     your sandbox organization's id
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

: "${INFRANEST_ORG:?Set INFRANEST_ORG to your sandbox organization id}"
ORG="/organizations/$INFRANEST_ORG"

echo "Resetting the sandbox to its sample data…"
infranest POST "$ORG/sandbox/reset" > /dev/null

zone=$(infranest GET "$ORG/dns-zones" | jq -r '(.data // .)[0].id')
echo "Using zone $zone."

body=$(jq -n '{type: "TXT", name: "smoke-test", value: "hello from the examples", ttl: 300}')
record=$(infranest POST "$ORG/dns-zones/$zone/dns-records" "$body" "smoke-test-$(date -u +%Y%m%d%H%M%S)" | jq -r .id)
echo "Created TXT record $record."

body=$(jq -n '{value: "changed by the examples"}')
echo "What changing it would do (dry run):"
infranest PUT "$ORG/dns-zones/$zone/dns-records/$record?dry_run=1" "$body" | jq '.changes'

infranest PUT "$ORG/dns-zones/$zone/dns-records/$record" "$body" > /dev/null
infranest DELETE "$ORG/dns-zones/$zone/dns-records/$record" > /dev/null
echo "Changed and deleted it again. Everything works."
