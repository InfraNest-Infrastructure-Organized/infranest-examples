#!/bin/sh
# Run the examples against an InfraNest sandbox, the way CI does: each one as a user would run it, with sandbox
# values, checking that it did what it says. What an example creates is removed again afterwards.
#
#   scripts/sandbox-run.sh                 every example, then reset the sandbox
#   scripts/sandbox-run.sh find            print the sandbox's id
#   scripts/sandbox-run.sh reset           put the sandbox's sample data back
#   scripts/sandbox-run.sh EXAMPLE...      only these, e.g. dynamic-dns acme-dns-01
#
#   INFRANEST_TOKEN   a TEST token made in your sandbox (123|in_test_…). A live token is refused, so this can
#                     never change a real organization.
#   INFRANEST_ORG     optional: the sandbox's id. Found from the token when not set.
#   INFRANEST_API     optional: https://api.infranest.io/api unless set.
#   PAUSE_SECONDS     optional: wait this long before each example (CI uses 15), to stay inside the rate limit.
#
# Needs sh, curl, jq, python3 and node; pwsh too for the PowerShell versions (skipped when it is missing).

# Variables for a single call are exported inside a subshell on purpose, so they never reach the next call.
# shellcheck disable=SC2030,SC2031
set -eu

cd "$(dirname "$0")/.."
API="${INFRANEST_API:-https://api.infranest.io/api}"
export INFRANEST_API="$API"
: "${INFRANEST_TOKEN:?Set INFRANEST_TOKEN to a test token from your sandbox}"

case "$INFRANEST_TOKEN" in
  *"|in_test_"* | in_test_*) ;;
  *)
    echo "INFRANEST_TOKEN is not a test token (123|in_test_…). These runs only ever use a sandbox." >&2
    exit 1
    ;;
esac

# Unique per run, so idempotency keys and names from one run never meet another's.
RUN="${GITHUB_RUN_ID:-local$(date -u +%s)}-${GITHUB_RUN_ATTEMPT:-1}"
WORK=$(mktemp -d)
CLEANUP="$WORK/cleanup"
: > "$CLEANUP"

# Undo what an example created, newest first: after each example, and on the way out when a check failed.
undo() {
  if [ -s "$CLEANUP" ]; then
    tail -r "$CLEANUP" 2>/dev/null || tac "$CLEANUP"
  fi | while read -r path; do
    api DELETE "$path" > /dev/null 2>&1 || echo "Could not remove $path; a reset removes it." >&2
  done
  : > "$CLEANUP"
}
cleanup() {
  status=$?
  undo
  rm -rf "$WORK"
  exit "$status"
}
trap cleanup EXIT
trap 'exit 1' INT TERM

# api METHOD PATH [JSON BODY] [IDEMPOTENCY KEY] — the same call the examples make, for this script's own checks.
# On a refusal it prints the API's answer to stderr, so it is in the log even when the output was captured.
api() {
  if [ -n "${3:-}" ]; then
    answer=$(curl -sS --fail-with-body -X "$1" "$API$2" \
      -H "Authorization: Bearer $INFRANEST_TOKEN" -H "Accept: application/json" \
      -H "Content-Type: application/json" ${4:+-H "Idempotency-Key: $4"} -d "$3") || { echo "$1 $2 answered: $answer" >&2; return 1; }
  else
    answer=$(curl -sS --fail-with-body -X "$1" "$API$2" \
      -H "Authorization: Bearer $INFRANEST_TOKEN" -H "Accept: application/json") || { echo "$1 $2 answered: $answer" >&2; return 1; }
  fi
  printf '%s\n' "$answer"
}

# A list answer may be a page ({"data": […]}) or a plain array.
ROWS='def rows: if type == "array" then . else .data end; '

remember() { echo "$1" >> "$CLEANUP"; }
forget() { grep -vxF "$1" "$CLEANUP" > "$CLEANUP.new" || true; mv "$CLEANUP.new" "$CLEANUP"; }
fail() { echo "::error::$*" >&2; exit 1; }
expect() { [ "$1" = "$2" ] || fail "$3: expected '$2', got '$1'"; }

# The languages to run an example in, minus PowerShell where it is not installed.
languages() {
  for lang in "$@"; do
    case "$lang" in
      ps1) command -v pwsh > /dev/null || { echo "  (pwsh is not installed; skipping the PowerShell version)" >&2; continue; } ;;
    esac
    echo "$lang"
  done
}

# run LANG FILE [ARGS…] — FILE without its extension; the extension and the interpreter follow LANG.
# Variables for one call go in a subshell, ( export X=1; run … ): an assignment written in front of a shell
# function may outlive the call in some shells.
run() {
  lang=$1 file=$2
  shift 2
  case "$lang" in
    sh) sh "$file.sh" "$@" ;;
    py) python3 "$file.py" "$@" ;;
    mjs) node "$file.mjs" "$@" ;;
    ps1) pwsh -NoProfile -NonInteractive -File "$file.ps1" "$@" ;;
  esac
}

find_sandbox() {
  if [ -z "${INFRANEST_ORG:-}" ]; then
    # A test token belongs to one sandbox, so it is the one organization the token sees.
    INFRANEST_ORG=$(api GET /auth/me |
      jq -r '[.user.organizations[]? | select(.is_sandbox == true) | .id] | if length == 1 then .[0] else empty end')
    [ -n "$INFRANEST_ORG" ] || fail "Could not find the sandbox this token belongs to. Set INFRANEST_ORG to its id."
  fi
  export INFRANEST_ORG
  ORG="/organizations/$INFRANEST_ORG"
}

reset_sandbox() {
  echo "Resetting sandbox $INFRANEST_ORG to its sample data."
  api POST "$ORG/sandbox/reset" > /dev/null
}

sample_zone() {
  # The sample zone sandbox-{id}.example.
  zone_json=$(api GET "$ORG/dns-zones?per_page=100" | jq -c "$ROWS"'[rows[] | select(.name | startswith("sandbox-"))][0] // rows[0]')
  ZONE_ID=$(echo "$zone_json" | jq -r .id)
  ZONE_NAME=$(echo "$zone_json" | jq -r .name)
  case "$ZONE_ID" in '' | null) fail "The sandbox has no DNS zone; reset it." ;; esac
  export ZONE_ID
}

record_value() {
  api GET "$ORG/dns-zones/$ZONE_ID/dns-records/$1" | jq -r .value
}

# The TXT records called NAME with VALUE (quotes around a TXT value are ignored).
count_txt() {
  api GET "$ORG/dns-zones/$ZONE_ID/dns-records?type=TXT&per_page=100" |
    jq --arg n "$1" --arg v "$2" "$ROWS"'[rows[] | select(.name == $n and ((.value | ltrimstr("\"") | rtrimstr("\"")) == $v))] | length'
}

first_monitor() {
  api GET "$ORG/monitoring-checks?per_page=100" | jq -r "$ROWS"'rows[0].id // empty'
}

monitor_with_target() {
  api GET "$ORG/monitoring-checks?per_page=100" | jq -r --arg t "$1" "$ROWS"'[rows[] | select(.target == $t)][0].id // empty'
}

# ── The examples ──────────────────────────────────────────────────────────────────────────────────────

example_sandbox_smoke_test() {
  for lang in $(languages sh py mjs); do
    echo "· $lang"
    case "$lang" in
      py) run py examples/sandbox-smoke-test/smoke_test ;;
      *) run "$lang" examples/sandbox-smoke-test/smoke-test ;;
    esac
  done
}

example_dynamic_dns() {
  sample_zone
  body=$(jq -n --arg name "ddns-$RUN" '{type: "A", name: $name, value: "192.0.2.1", ttl: 300}')
  RECORD_ID=$(api POST "$ORG/dns-zones/$ZONE_ID/dns-records" "$body" "ddns-$RUN" | jq -r .id)
  export RECORD_ID
  remember "$ORG/dns-zones/$ZONE_ID/dns-records/$RECORD_ID"

  for lang in $(languages sh py mjs ps1); do
    echo "· $lang"
    api PUT "$ORG/dns-zones/$ZONE_ID/dns-records/$RECORD_ID" '{"value": "192.0.2.1", "ttl": 300}' > /dev/null
    case "$lang" in py) file=examples/dynamic-dns/update_dns ;; ps1) file=examples/dynamic-dns/Update-Dns ;; *) file=examples/dynamic-dns/update-dns ;; esac

    (export ADDRESS=203.0.113.10 DRY_RUN=1; run "$lang" "$file")
    expect "$(record_value "$RECORD_ID")" 192.0.2.1 "$lang: a dry run changed the record"

    (export ADDRESS=203.0.113.10; run "$lang" "$file")
    expect "$(record_value "$RECORD_ID")" 203.0.113.10 "$lang: the record was not updated"

    unchanged=$(export ADDRESS=203.0.113.10; run "$lang" "$file") || fail "$lang: the second run failed: $unchanged"
    expect "$unchanged" "" "$lang: a second run with the same address should send nothing"
  done
}

example_dynamic_ip() {
  sample_zone
  # The sandbox's sample source, Office, keeps the A record `office` (a token cannot create a source).
  DYNAMIC_IP_ID=$(api GET "$ORG/dynamic-ips" | jq -r "$ROWS"'[rows[] | select(.label == "Office")][0].id // empty')
  [ -n "$DYNAMIC_IP_ID" ] || fail "The sandbox has no Office dynamic IP; reset it."
  export DYNAMIC_IP_ID
  office=$(api GET "$ORG/dns-zones/$ZONE_ID/dns-records?type=A&per_page=100" | jq -r "$ROWS"'[rows[] | select(.name == "office")][0].id // empty')
  [ -n "$office" ] || fail "The sandbox has no office record; reset it."
  sample='{"ipv4": "198.51.100.7"}'
  api PUT "$ORG/dynamic-ips/$DYNAMIC_IP_ID/address" "$sample" > /dev/null

  echo "· set-address.sh"
  changed=$(export ADDRESS=203.0.113.20; sh examples/dynamic-ip/set-address.sh)
  expect "$changed" "Changed to 203.0.113.20; 1 record(s) updated" "set-address.sh: the address was not set"
  # The records follow on the queue; give them a moment.
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ "$(record_value "$office")" = 203.0.113.20 ] && break
    sleep 2
  done
  expect "$(record_value "$office")" 203.0.113.20 "set-address.sh: the office record did not follow"
  unchanged=$(export ADDRESS=203.0.113.20; sh examples/dynamic-ip/set-address.sh) || fail "set-address.sh: the second run failed: $unchanged"
  expect "$unchanged" "" "set-address.sh: a second run with the same address should print nothing"

  # The update endpoint needs the source's password, which only the app shows; a wrong one must fail loudly.
  echo "· dyn-update.sh"
  if refused=$(export DYN_USER=dyn_nobody DYN_PASSWORD="wrong-$RUN" DYN_URL="$API/dyn"; sh examples/dynamic-ip/dyn-update.sh); then
    fail "dyn-update.sh: a wrong password should exit non-zero"
  fi
  expect "$refused" badauth "dyn-update.sh: a wrong password"

  api PUT "$ORG/dynamic-ips/$DYNAMIC_IP_ID/address" "$sample" > /dev/null
}

example_acme_dns_01() {
  sample_zone
  export TMPDIR="$WORK" PROPAGATION_SECONDS=0
  for domain in "$ZONE_NAME" "www.$ZONE_NAME"; do
    name=_acme-challenge
    [ "$domain" = "$ZONE_NAME" ] || name=_acme-challenge.www
    validation="ci-$RUN-$(date -u +%s)"
    echo "· $domain"
    CERTBOT_DOMAIN=$domain CERTBOT_VALIDATION=$validation sh examples/acme-dns-01/auth-hook.sh
    expect "$(count_txt "$name" "$validation")" 1 "auth-hook.sh should add one TXT record $name"
    CERTBOT_DOMAIN=$domain CERTBOT_VALIDATION=$validation sh examples/acme-dns-01/cleanup-hook.sh
    expect "$(count_txt "$name" "$validation")" 0 "cleanup-hook.sh should remove the TXT record $name"
  done
}

example_maintenance_window() {
  CHECK_IDS=$(first_monitor)
  [ -n "$CHECK_IDS" ] || fail "The sandbox has no monitor; reset it."
  export CHECK_IDS NAME="CI run of the examples" MINUTES=10
  for lang in $(languages sh py mjs ps1); do
    echo "· $lang"
    case "$lang" in ps1) file=examples/maintenance-window/Maintenance ;; *) file=examples/maintenance-window/maintenance ;; esac
    window=$(export DEPLOY_ID="ci-$RUN-$lang"; run "$lang" "$file" open) || fail "$lang: open failed: $window"
    case "$window" in '' | *[!0-9]*) fail "$lang: open should print the new window's id, printed '$window'" ;; esac
    remember "$ORG/maintenance-windows/$window"
    found=$(api GET "$ORG/maintenance-windows?per_page=100" | jq --argjson id "$window" "$ROWS"'[rows[] | select(.id == $id)] | length')
    expect "$found" 1 "$lang: window $window is not listed"
    (export WINDOW_ID="$window"; run "$lang" "$file" close)
  done
}

example_monitor_per_deploy() {
  for lang in $(languages sh py mjs); do
    echo "· $lang"
    case "$lang" in py) file=examples/monitor-per-deploy/create_monitor ;; *) file=examples/monitor-per-deploy/create-monitor ;; esac
    target="https://ci-$RUN-$lang.example.com/health"
    first=$(export NAME="CI $lang" TARGET="$target" INTERVAL=300; run "$lang" "$file") || fail "$lang: failed: $first"
    remember "$ORG/monitoring-checks/$first"
    again=$(export NAME="CI $lang" TARGET="$target" INTERVAL=300; run "$lang" "$file") || fail "$lang: the second run failed: $again"
    expect "$again" "$first" "$lang: a second run should find the monitor, not create another"
    expect "$(monitor_with_target "$target")" "$first" "$lang: the monitor is not listed with its target"

    if [ "$lang" = sh ]; then
      MONITOR_ID=$first sh examples/monitor-per-deploy/pause-resume.sh pause
      MONITOR_ID=$first sh examples/monitor-per-deploy/pause-resume.sh resume
    fi
    # One at a time, so the sandbox's small monitor limit is never in the way.
    api DELETE "$ORG/monitoring-checks/$first" > /dev/null
    forget "$ORG/monitoring-checks/$first"
  done
}

example_watch_new_server() {
  # The sandbox's sample server. The website URL stays the same between runs: the example's idempotency key is
  # tied to the server, so a different body within 24 hours would be refused as a reused key.
  website=https://web-01.example.com
  # web-01 is self-managed, which the server list includes only when asked for by provider.
  server=$(api GET "$ORG/cloud-servers?search=web-01&provider=self_managed" | jq -r '[.data[] | select(.name == "web-01")][0].id // empty')
  [ -n "$server" ] || fail "The sandbox has no server web-01; reset it."
  SERVER_NAME=web-01 WEBSITE_URL=$website sh examples/watch-new-server/watch-server.sh
  remember "$ORG/cloud-servers/$server/monitoring"
  expect "$(api GET "$ORG/cloud-servers/$server" | jq -r .monitoring_enabled)" true \
    "monitoring is not on for web-01"
  monitor=$(monitor_with_target "$website")
  # Empty only when this key was replayed from an earlier run in the last 24 hours, before a reset removed it.
  [ -z "$monitor" ] || remember "$ORG/monitoring-checks/$monitor"
}

example_quickstart() {
  # The developer site's quickstart, as written: it checks each step's answer itself and undoes its own change.
  sh examples/quickstart/quickstart.sh
}

example_audit_log_to_siem() {
  # Today's log: this run's own changes, and the reset, are in it.
  day=$(date -u +%Y-%m-%d)
  DAY=$day OUT_DIR="$WORK" sh examples/audit-log-to-siem/export-audit-log.sh
  file="$WORK/audit-$day.jsonl"
  [ -f "$file" ] || fail "export-audit-log.sh wrote no file"
  jq -e . "$file" > /dev/null || fail "audit-$day.jsonl is not one JSON object per line"
  [ -s "$file" ] || echo "::warning::The sandbox's audit log for $day is empty."
}

example_status_and_uptime() {
  monitor=$(first_monitor)
  [ -n "$monitor" ] || fail "The sandbox has no monitor; reset it."
  echo "· status.sh"
  sh examples/status-and-uptime/status.sh | tee "$WORK/status.txt"
  grep -q '^Light: ' "$WORK/status.txt" || fail "status.sh printed no traffic light"
  echo "· uptime.sh, one monitor"
  MONITOR_ID=$monitor PERIOD=7d HOURLY=1 sh examples/status-and-uptime/uptime.sh
  MONITOR_ID=$monitor MONTH=$(date -u +%Y-%m) sh examples/status-and-uptime/uptime.sh
  echo "· uptime.sh, the monthly report"
  sh examples/status-and-uptime/uptime.sh
}

example_mcp() {
  echo "· check-connection.sh"
  INFRANEST_MCP="${API%/api}/mcp" sh examples/mcp/check-connection.sh | tee "$WORK/mcp.txt"
  grep -q '^Connected to ' "$WORK/mcp.txt" || fail "check-connection.sh did not connect"
  grep -q "^  $INFRANEST_ORG " "$WORK/mcp.txt" || fail "check-connection.sh did not list the sandbox"
}

ALL="sandbox-smoke-test quickstart dynamic-dns dynamic-ip acme-dns-01 maintenance-window monitor-per-deploy watch-new-server status-and-uptime audit-log-to-siem mcp"

find_sandbox
# shellcheck disable=SC2086 # $ALL is a list of names, split on purpose
[ $# -gt 0 ] || set -- reset $ALL reset

for example in "$@"; do
  case "$example" in
    find) echo "$INFRANEST_ORG"; continue ;;
    reset) reset_sandbox; continue ;;
  esac
  case " $ALL " in *" $example "*) ;; *) fail "No example called $example. Known: $ALL" ;; esac
  # A pause first keeps a whole run inside the token's 60 changes a minute.
  sleep "${PAUSE_SECONDS:-0}"
  echo "::group::$example"
  "example_$(echo "$example" | tr - _)"
  undo
  echo "::endgroup::"
  echo "✓ $example"
done
