#!/bin/sh
# Check that a token reaches the InfraNest MCP server before you put it in an assistant: lists the tools it is
# offered and the organizations it can read.
#
#   INFRANEST_TOKEN   an API token (a test token for your sandbox to start)
#   INFRANEST_MCP     optional: https://api.infranest.io/mcp unless set
#
# POSIX sh with curl and jq.
set -eu

: "${INFRANEST_TOKEN:?Set INFRANEST_TOKEN to an API token.}"
MCP="${INFRANEST_MCP:-https://api.infranest.io/mcp}"

mcp() {
  curl -sS --fail-with-body "$MCP" \
    -H "Authorization: Bearer $INFRANEST_TOKEN" \
    -H 'Accept: application/json, text/event-stream' \
    -H 'Content-Type: application/json' \
    -d "$1"
}

tools=$(mcp '{"jsonrpc":"2.0","id":1,"method":"tools/list"}' | jq -r '.result.tools[].name')
count=$(printf '%s\n' "$tools" | grep -c .)
echo "Connected to $MCP: $count tools."
printf '%s\n' "$tools" | grep -qx status_overview || { echo "status_overview is missing: is this the InfraNest MCP server?" >&2; exit 1; }

echo "Organizations this token reads:"
mcp '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"list_organizations","arguments":{}}}' \
  | jq -r '.result.content[0].text | fromjson | (if type == "object" then .organizations else . end)[] | "  \(.id)  \(.name)"'
