#!/bin/sh
# Verify that a webhook delivery came from InfraNest. https://developers.infranest.io/webhooks#verify-the-signature
#
#   ./verify.sh BODY_FILE TIMESTAMP SIGNATURE     (X-InfraNest-Timestamp, X-InfraNest-Signature-V2)
#   INFRANEST_WEBHOOK_SECRET   the endpoint's signing secret (whsec_…)
# Exits 0 for a genuine delivery, 1 otherwise. Needs openssl.
set -eu
BODY_FILE=$1 TIMESTAMP=$2 SIGNATURE=$3
: "${INFRANEST_WEBHOOK_SECRET:?Set INFRANEST_WEBHOOK_SECRET to the signing secret of the endpoint}"

case "$TIMESTAMP" in '' | *[!0-9]*) exit 1 ;; esac
age=$(( $(date -u +%s) - TIMESTAMP ))
[ "$age" -le 300 ] && [ "$age" -ge -300 ] || exit 1
expected="sha256=$({ printf '%s.' "$TIMESTAMP"; cat "$BODY_FILE"; } | openssl dgst -sha256 -hmac "$INFRANEST_WEBHOOK_SECRET" | awk '{print $NF}')"
[ "$expected" = "$SIGNATURE" ]
