#!/bin/sh
# The developer site's quickstart, step by step: find your sandbox, read its sample zones, try a DNS record as a dry
# run, create it, and undo the change from the zone's history. Each step checks the answer the quickstart page shows.
# https://developers.infranest.io/quickstart
#
#   INFRANEST_TOKEN   a test token made in your sandbox (it starts with in_test_ after the id), DNS read and write
#   INFRANEST_ORG     optional: your sandbox's id. Found from the token when not set.
set -eu

API="${INFRANEST_API:-https://api.infranest.io/api}"
: "${INFRANEST_TOKEN:?Set INFRANEST_TOKEN to a test token from your sandbox}"
case "$INFRANEST_TOKEN" in
  *"|in_test_"* | in_test_*) ;;
  *) echo "The quickstart uses a test token from your sandbox (123|in_test_…)." >&2; exit 1 ;;
esac

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

expect() { [ "$1" = "$2" ] || { echo "Step $3: expected '$2', got '$1'" >&2; exit 1; }; }

echo "2. Find your sandbox"
if [ -z "${INFRANEST_ORG:-}" ]; then
  INFRANEST_ORG=$(infranest GET "/auth/me" | jq -r '[.user.organizations[] | select(.is_sandbox == true) | .id][0] // empty')
fi
[ -n "$INFRANEST_ORG" ] || { echo "This token sees no sandbox." >&2; exit 1; }
ORG="/organizations/$INFRANEST_ORG"
echo "   sandbox $INFRANEST_ORG"

echo "3. Read the sample zones"
zones=$(infranest GET "$ORG/dns-zones")
echo "$zones" | jq -c '.data[] | {id, name, records_count}'
ZONE=$(echo "$zones" | jq -r --arg n "sandbox-$INFRANEST_ORG.example" '[.data[] | select(.name == $n) | .id][0] // empty')
[ -n "$ZONE" ] || { echo "Step 3: no zone sandbox-$INFRANEST_ORG.example — reset the sandbox (scripts/sandbox-run.sh reset)." >&2; exit 1; }

RECORD='{"type": "A", "name": "quickstart", "value": "192.0.2.50", "ttl": 3600}'

echo "4. Try the change as a dry run"
dry=$(infranest POST "$ORG/dns-zones/$ZONE/dns-records?dry_run=1" "$RECORD")
expect "$(echo "$dry" | jq -r '.dry_run')" true 4
expect "$(echo "$dry" | jq -r '.changes[0].action')" create 4
expect "$(echo "$dry" | jq -r '.changes[0].after.value')" 192.0.2.50 4

echo "5. Make the change"
KEY="quickstart-${GITHUB_RUN_ID:-local}-$(date -u +%s)"
created=$(infranest POST "$ORG/dns-zones/$ZONE/dns-records" "$RECORD" "$KEY")
expect "$(echo "$created" | jq -r '.name')" quickstart 5
RECORD_ID=$(echo "$created" | jq -r '.id')
echo "   record $RECORD_ID"

echo "6. Undo it"
BATCH=$(infranest GET "$ORG/dns-zones/$ZONE/changes" | jq -r '.batches[0].batch_id')
undone=$(infranest POST "$ORG/dns-changes/undo" "{\"batch_id\": \"$BATCH\"}")
expect "$(echo "$undone" | jq -r '.undone')" 1 6
expect "$(echo "$undone" | jq -r '.results[0].outcome')" undone 6
left=$(infranest GET "$ORG/dns-zones/$ZONE/dns-records?type=A" | jq --argjson id "$RECORD_ID" '[if type == "array" then .[] else .data[] end | select(.id == $id)] | length')
expect "$left" 0 6
echo "Done: the record was created and undone."
