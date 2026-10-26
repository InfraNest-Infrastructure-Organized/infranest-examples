#!/bin/sh
# Add the InfraNest MCP server to Claude Code, reading the token from INFRANEST_TOKEN.
# The token is passed to Claude Code's own configuration, never written into this repository.
set -eu

: "${INFRANEST_TOKEN:?Set INFRANEST_TOKEN to an API token (a test token for your sandbox to start).}"

claude mcp add --transport http infranest https://api.infranest.io/mcp \
  --header "Authorization: Bearer $INFRANEST_TOKEN"

echo "Added. In Claude Code, ask: Is anything down in InfraNest right now?"
