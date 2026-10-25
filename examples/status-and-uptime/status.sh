#!/bin/sh
# Is everything up right now? One call answers it: every monitor and server, the open incidents and the
# maintenance running now. Prints a summary and a traffic light — for a dashboard, a chat bot or a cron job.
#
#   INFRANEST_TOKEN   a token with Monitoring → Read (add Servers → Read to include your servers)
#   INFRANEST_ORG     your organization's id
#   TAG               optional: a tag's id, to see only one customer's or one team's monitors and servers
#   STRICT            1 to exit with status 1 when the light is not green, for a health check or an alert
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

status=$(infranest GET "/organizations/$INFRANEST_ORG/status${TAG:+?tag=$TAG}")

echo "$status" | jq -r '
  .summary as $s
  | "Monitors:    \($s.monitors.total) — \($s.monitors.up) up, \($s.monitors.down) down, \($s.monitors.degraded) degraded, \($s.monitors.paused) paused, \($s.monitors.unknown) unknown",
    (if $s.servers == null then "Servers:     not included (the token has no Servers scope)"
     else "Servers:     \($s.servers.total) — \($s.servers.running) running, \($s.servers.agent_not_reporting) agent not reporting, \($s.servers.breaching) breaching an alert" end),
    "Incidents:   \($s.open_incidents) open",
    "Maintenance: \($s.active_maintenance) running now",
    (.monitors[]? | select(.status == "down" or .status == "degraded") | "  \(.status): \(.name)"),
    (.incidents[]? | "  incident since \(.started_at): \(.title)")'

# Green when nothing is down or slow and no incident is open.
if echo "$status" | jq -e '.summary.monitors.down + .summary.monitors.degraded == 0 and .summary.open_incidents == 0' > /dev/null; then
  echo "Light:       green"
else
  echo "Light:       red"
  [ "${STRICT:-0}" = "1" ] && exit 1
fi
exit 0
