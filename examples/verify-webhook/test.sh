#!/bin/sh
# Every verifier in this folder against the same deliveries, signed here the way InfraNest signs them: with a
# timestamp (test deliveries), without one (events sent by an automation today), a tampered body, a stale timestamp
# and a wrong secret. Each must accept the first two and refuse the rest. CI runs this; so can you.
#
# Needs openssl, node, python3, php, go and pwsh; a missing one is skipped with a note.
set -eu
cd "$(dirname "$0")"
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

export INFRANEST_WEBHOOK_SECRET=whsec_example_0123456789abcdefghijklmnopqrstuvwxyzABCDEF
printf '%s' '{"event":"monitor.alert","created_at":"2026-01-15T09:30:00.000000Z","data":{"check_name":"Website","status":"down","monitor_type":"http"}}' > "$WORK/body.json"
printf '%s' '{"event":"monitor.alert","created_at":"2026-01-15T09:30:00.000000Z","data":{"check_name":"Website","status":"up","monitor_type":"http"}}' > "$WORK/tampered.json"

now=$(date -u +%s)
stale=$((now - 3600))
sign() { printf '%s' "$1" | openssl dgst -sha256 -hmac "$2" | awk '{print "sha256=" $NF}'; }
body=$(cat "$WORK/body.json")
with_ts=$(sign "$now.$body" "$INFRANEST_WEBHOOK_SECRET")
stale_ts=$(sign "$stale.$body" "$INFRANEST_WEBHOOK_SECRET")
body_only=$(sign "$body" "$INFRANEST_WEBHOOK_SECRET")
wrong_secret=$(sign "$now.$body" whsec_not_the_secret)

failures=0
check() { # NAME WANT(0|1) COMMAND…
  name=$1 want=$2
  shift 2
  if "$@" > /dev/null 2>&1; then got=0; else got=1; fi
  if [ "$got" = "$want" ]; then echo "  ok    $name"; else echo "  FAIL  $name (exit $got, wanted $want)"; failures=$((failures + 1)); fi
}

for lang in sh node python3 php go pwsh; do
  case "$lang" in
    sh) cmd="sh verify.sh" ;;
    node) cmd="node verify.mjs" ;;
    python3) cmd="python3 verify.py" ;;
    php) cmd="php verify.php" ;;
    go) cmd="go run verify.go" ;;
    pwsh) cmd="pwsh -NoProfile -NonInteractive -File Verify-Webhook.ps1" ;;
  esac
  if [ "$lang" != sh ] && ! command -v "$lang" > /dev/null; then
    echo "$lang: not installed, skipped"
    continue
  fi
  echo "$lang"
  # shellcheck disable=SC2086 # $cmd is a command and its arguments, split on purpose
  {
    check "accepts a timestamped delivery" 0 $cmd "$WORK/body.json" "$now" "$with_ts"
    check "accepts a body-only signature" 0 $cmd "$WORK/body.json" "" "$body_only"
    check "refuses a tampered body" 1 $cmd "$WORK/tampered.json" "$now" "$with_ts"
    check "refuses a stale timestamp" 1 $cmd "$WORK/body.json" "$stale" "$stale_ts"
    check "refuses another secret" 1 $cmd "$WORK/body.json" "$now" "$wrong_secret"
  }
done

[ "$failures" -eq 0 ] || { echo "$failures check(s) failed"; exit 1; }
echo "Every verifier agrees."
