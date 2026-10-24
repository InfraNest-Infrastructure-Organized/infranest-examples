#!/bin/sh
# Certbot --manual-auth-hook: prove you own a domain with a TXT record in InfraNest DNS. Wildcards work too.
#
#   certbot certonly --manual --preferred-challenges dns \
#     --manual-auth-hook ./auth-hook.sh --manual-cleanup-hook ./cleanup-hook.sh -d example.com -d '*.example.com'
#
#   INFRANEST_TOKEN   a token with DNS → Write, and nothing else
#   INFRANEST_ORG     your organization's id
#   ZONE_ID           the id of the zone that holds the domain
#   Certbot sets CERTBOT_DOMAIN and CERTBOT_VALIDATION.
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
ZONE="/organizations/$INFRANEST_ORG/dns-zones/$ZONE_ID"

zone_name=$(infranest GET "$ZONE" | jq -r .name)
# The record's name, relative to the zone: _acme-challenge, or _acme-challenge.sub for sub.example.com.
sub=${CERTBOT_DOMAIN%"$zone_name"}
sub=${sub%.}
name="_acme-challenge${sub:+.$sub}"

body=$(jq -n --arg name "$name" --arg value "$CERTBOT_VALIDATION" '{type: "TXT", name: $name, value: $value, ttl: 60}')
id=$(infranest POST "$ZONE/dns-records" "$body" "acme-$CERTBOT_DOMAIN-$CERTBOT_VALIDATION" | jq -r .id)

# Remembered for the cleanup hook.
echo "$id" > "${TMPDIR:-/tmp}/infranest-acme-$CERTBOT_DOMAIN-$CERTBOT_VALIDATION"

# Give resolvers a moment to see the new record before Let's Encrypt looks.
sleep "${PROPAGATION_SECONDS:-30}"
