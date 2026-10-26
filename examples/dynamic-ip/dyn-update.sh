#!/bin/sh
# Report this connection's public address to an InfraNest Dynamic IP source, over the dyndns2 update endpoint.
# Every record the source keeps follows, with a history and an alert when the address changes. Run it every few
# minutes from cron or the systemd timer next to it. Needs no API token: the source's own update password can do
# this one thing and nothing else.
#
#   DYN_USER       the source's public id     (Automations → Dynamic IPs → the source)
#   DYN_PASSWORD   the source's update password
#   ADDRESS        optional: report this IPv4 address instead of the one the request comes from
#   ADDRESS6       optional: report this IPv6 address too
#   DYN_URL        optional: https://dyn.infranest.io/ unless set
#
# Prints InfraNest's answer: `good <address>` when it changed, `nochg <address>` when it did not.
# Exits non-zero on `badauth` (wrong id or password) and `nohost` (no usable address).
set -eu

: "${DYN_USER:?Set DYN_USER to the public id of the source}" "${DYN_PASSWORD:?Set DYN_PASSWORD to its update password}"
url="${DYN_URL:-https://dyn.infranest.io/}"

# The password goes in Basic auth, never in the URL, so it stays out of logs. curl reads it from stdin here, so it
# is not on the command line either, where `ps` would show it.
answer=$(printf 'user = "%s:%s"\n' "$DYN_USER" "$DYN_PASSWORD" |
  curl -sS -K - -G "$url" ${ADDRESS:+--data-urlencode "myip=$ADDRESS"} ${ADDRESS6:+--data-urlencode "myipv6=$ADDRESS6"}) || {
  echo "Could not reach $url" >&2
  exit 1
}

echo "$answer"
case "$answer" in
  good* | nochg*) ;;
  *) exit 1 ;;
esac
