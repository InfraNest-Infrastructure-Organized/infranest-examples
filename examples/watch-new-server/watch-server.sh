#!/bin/sh
# Start watching a server you just created at your cloud provider: turn on monitoring, and check its website.
#
#   INFRANEST_TOKEN   a token with Servers → Write and Monitoring → Write
#   INFRANEST_ORG     your organization's id
#   SERVER_NAME       the server's name, e.g. web-03
#   WEBSITE_URL       optional: a URL on the server to watch, e.g. https://web-03.example.com
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

: "${INFRANEST_ORG:?Set INFRANEST_ORG}" "${SERVER_NAME:?Set SERVER_NAME}"
ORG="/organizations/$INFRANEST_ORG"

server=$(infranest GET "$ORG/cloud-servers?search=$SERVER_NAME" | jq -r --arg n "$SERVER_NAME" '[.data[] | select(.name == $n)][0].id // empty')
if [ -z "$server" ]; then
  echo "No server called $SERVER_NAME yet. InfraNest syncs with your provider on a schedule; select Sync now in the app to fetch it at once." >&2
  exit 1
fi

infranest POST "$ORG/cloud-servers/$server/monitoring" | jq -r '"Monitoring on (\(.usage) of \(.limit // "unlimited") monitored servers)."'

if [ -n "${WEBSITE_URL:-}" ]; then
  body=$(jq -n --arg name "$SERVER_NAME website" --arg target "$WEBSITE_URL" '{name: $name, type: "http", target: $target, interval_seconds: 60}')
  infranest POST "$ORG/monitoring-checks" "$body" "server-$server-website" > /dev/null
  echo "Watching $WEBSITE_URL."
fi
