#!/bin/sh
# Uptime and response times for a period. With MONITOR_ID: one monitor's uptime, p50 and p95 response time and
# incidents, and with HOURLY=1 its results hour by hour. Without it: the monthly uptime report, every monitor.
#
#   INFRANEST_TOKEN   a token with Monitoring → Read
#   INFRANEST_ORG     your organization's id
#   MONITOR_ID        optional: one monitor's id (GET /organizations/{org}/monitoring-checks)
#   PERIOD            24h, 7d, 30d (default) or 90d                                     (with MONITOR_ID)
#   MONTH             a calendar month, YYYY-MM, instead of PERIOD; for the report, default the last full month
#   HOURLY            1 to also print the last 24 hours, hour by hour                    (with MONITOR_ID)
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
# A percentage, or "no data" when nothing was measured (a new monitor, or one that never ran).
PCT='def pct: if . == null then "no data" else "\(.)%" end; '

hours_ago() {
  # GNU date (Linux, most CI) or BSD date (macOS).
  date -u -d "-$1 hours" +%Y-%m-%dT%H:00:00Z 2>/dev/null || date -u -v "-$1H" +%Y-%m-%dT%H:00:00Z
}

if [ -z "${MONITOR_ID:-}" ]; then
  # Every monitor at once, for one calendar month.
  infranest GET "$ORG/uptime-report${MONTH:+?month=$MONTH}" | jq -r "$PCT"'
    "Uptime in \(.month)\(if .closed then "" else " (so far)" end):",
    (.checks[] | "  \(.uptime_pct | pct)\t\(.downtime_minutes) min down\t\(.incidents) incidents\t\(.name)"),
    "Worst: \(.summary.worst_uptime_pct | pct), mean: \(.summary.mean_uptime_pct | pct), \(.summary.incidents) incidents"'
  exit 0
fi

if [ -n "${MONTH:-}" ]; then
  # A calendar month: from the first of MONTH to the first of the next one.
  year=${MONTH%-*}
  month=${MONTH#*-}
  month=${month#0}
  if [ "$month" -eq 12 ]; then next=$(printf '%04d-01' $((year + 1))); else next=$(printf '%04d-%02d' "$year" $((month + 1))); fi
  window="from=$MONTH-01T00:00:00Z&to=$next-01T00:00:00Z"
else
  window="period=${PERIOD:-30d}"
fi

infranest GET "$ORG/monitoring-checks/$MONITOR_ID/aggregates?$window" | jq -r "$PCT"'
  "Monitor \(.monitoring_check_id), \(.from) to \(.to):",
  "  Uptime:         \(.uptime_percent | pct)  (checks up: \(.up_percent | pct))",
  "  Checks:         \(.checks.total) — \(.checks.up) up, \(.checks.degraded) slow, \(.checks.down) failed",
  "  Response time:  p50 \(.response_time_ms.p50 // "–") ms, p95 \(.response_time_ms.p95 // "–") ms",
  "  Incidents:      \(.incidents.count), \(.incidents.down_minutes) minutes down"'

if [ "${HOURLY:-0}" = "1" ]; then
  echo "Last 24 hours, newest first:"
  infranest GET "$ORG/monitoring-checks/$MONITOR_ID/results?resolution=hour&from=$(hours_ago 24)&to=$(hours_ago 0)&per_page=24" | jq -r "$PCT"'
    if (.data | length) == 0 then "  no results in this window"
    else .data[] | "  \(.time)\t\(.up_percent | pct) up\t\(.checks_total) checks\tp95 \(.response_p95_ms // "–") ms" end'
fi
