#!/bin/sh
# Pause a monitor before a deploy and resume it afterwards.
#
#   pause-resume.sh pause|resume
#
#   INFRANEST_TOKEN   a token with Monitoring → Write
#   INFRANEST_ORG     your organization's id
#   MONITOR_ID        the monitor's id
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

: "${INFRANEST_ORG:?Set INFRANEST_ORG}" "${MONITOR_ID:?Set MONITOR_ID}"

case "${1:-}" in
  pause)  infranest POST "/organizations/$INFRANEST_ORG/monitoring-checks/$MONITOR_ID/pause" > /dev/null ;;
  resume) infranest POST "/organizations/$INFRANEST_ORG/monitoring-checks/$MONITOR_ID/resume" > /dev/null ;;
  *) echo "Usage: pause-resume.sh pause|resume" >&2; exit 2 ;;
esac
echo "Monitor $MONITOR_ID: ${1}d."
