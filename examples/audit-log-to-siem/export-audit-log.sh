#!/bin/sh
# Write one day of your organization's audit log as JSON lines — the format log shippers read.
# Run it daily, shortly after midnight UTC, and point Filebeat, Vector or the Splunk forwarder at the files.
#
#   INFRANEST_TOKEN   a token with Audit log → Read
#   INFRANEST_ORG     your organization's id
#   DAY               the day to export, YYYY-MM-DD (default: yesterday, UTC)
#   OUT_DIR           where to write audit-YYYY-MM-DD.jsonl (default: .)
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
day=${DAY:-$(date -u -d yesterday +%Y-%m-%d 2>/dev/null || date -u -v-1d +%Y-%m-%d)}
out="${OUT_DIR:-.}/audit-$day.jsonl"
page=1

: > "$out"
while :; do
  answer=$(infranest GET "/organizations/$INFRANEST_ORG/audit-logs?from=$day&to=$day&per_page=100&page=$page")
  echo "$answer" | jq -c '.data[]' >> "$out"
  [ "$(echo "$answer" | jq -r .next_page_url)" = "null" ] && break
  page=$((page + 1))
done
echo "Wrote $(wc -l < "$out" | tr -d ' ') entries to $out"
