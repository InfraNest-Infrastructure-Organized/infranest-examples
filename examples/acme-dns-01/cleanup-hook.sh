#!/bin/sh
# Certbot --manual-cleanup-hook: remove the TXT record auth-hook.sh added.
#
#   INFRANEST_TOKEN, INFRANEST_ORG and ZONE_ID as for auth-hook.sh.
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

: "${INFRANEST_ORG:?Set INFRANEST_ORG}" "${ZONE_ID:?Set ZONE_ID}"
state="${TMPDIR:-/tmp}/infranest-acme-$CERTBOT_DOMAIN-$CERTBOT_VALIDATION"

[ -f "$state" ] || exit 0
infranest DELETE "/organizations/$INFRANEST_ORG/dns-zones/$ZONE_ID/dns-records/$(cat "$state")" > /dev/null
rm -f "$state"
