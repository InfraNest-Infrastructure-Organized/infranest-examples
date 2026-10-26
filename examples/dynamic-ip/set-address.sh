#!/bin/sh
# Set a Dynamic IP source's address with an API token: for a deploy step, a cloud hook or a script that already
# knows the new address. Everything a router's update does follows: the records, the history, the alert and the
# `dynamic_ip.changed` event. Sending the address it already has changes nothing.
#
#   INFRANEST_TOKEN   a token with Monitoring → Write (dynamic IPs sit under the Monitoring scope)
#   INFRANEST_ORG     your organization's id
#   DYNAMIC_IP_ID     the source's id       (GET /organizations/{org}/dynamic-ips)
#   ADDRESS           the IPv4 address; looked up when neither it nor ADDRESS6 is set
#   ADDRESS6          optional: the IPv6 address
#
# A source that keeps a firewall rule open is refused (403 not_token_writable): a new address there changes who
# can reach the server. Report its address with dyn-update.sh, or change it in the app.
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

: "${INFRANEST_ORG:?Set INFRANEST_ORG}" "${DYNAMIC_IP_ID:?Set DYNAMIC_IP_ID}"

if [ -z "${ADDRESS:-}" ] && [ -z "${ADDRESS6:-}" ]; then
  ADDRESS=$(curl -fsS https://api.ipify.org)
fi
# A family left out stays as it is.
body=$(jq -n --arg v4 "${ADDRESS:-}" --arg v6 "${ADDRESS6:-}" '{ipv4: (if $v4 == "" then null else $v4 end), ipv6: (if $v6 == "" then null else $v6 end)}')

answer=$(infranest PUT "/organizations/$INFRANEST_ORG/dynamic-ips/$DYNAMIC_IP_ID/address" "$body")

# Silent when nothing changed, so cron mails only real changes.
if [ "$(echo "$answer" | jq -r .changed)" = "true" ]; then
  echo "$answer" | jq -r '"Changed to \([.current_ipv4, .current_ipv6] | map(select(. != null)) | join(" and ")); \(.applied) record(s) updated"'
fi
