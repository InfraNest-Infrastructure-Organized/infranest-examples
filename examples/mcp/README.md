# Ask your AI assistant about your infrastructure (MCP)

Connect Claude, ChatGPT, Cursor, VS Code or Claude Desktop to InfraNest, then ask in plain words: what is down, why
it broke and what changed just before, where a name points, what expires soon. The assistant reads through the
InfraNest MCP server, with the same rules as your API token.

Docs: [The MCP server](https://developers.infranest.io/ai-assistants)

**claude.ai and ChatGPT** need no file here: add InfraNest as a connector, sign in, and pick the organization —
see [Connect Claude or ChatGPT](https://infranest.io/docs/connect-claude-or-chatgpt/).

| File | For |
|---|---|
| [`check-connection.sh`](check-connection.sh) | Any client: checks the token reaches the server, and lists the tools and organizations it gets |
| [`add-to-claude-code.sh`](add-to-claude-code.sh) | Claude Code: adds the server, reading the token from `INFRANEST_TOKEN` |
| [`cursor-mcp.json`](cursor-mcp.json) | Cursor: `~/.cursor/mcp.json`, or `.cursor/mcp.json` in a project; reads `INFRANEST_TOKEN` from the environment |
| [`vscode-mcp.json`](vscode-mcp.json) | VS Code: `.vscode/mcp.json`; asks for the token once and keeps it in VS Code's secret storage |
| [`claude-desktop-config.json`](claude-desktop-config.json) | Claude Desktop with a token, through the `mcp-remote` bridge (needs Node.js). The claude.ai connector is simpler |

**Token:** create one under **My account → Developer**, with **read** access to the areas the assistant should see.
Add **Monitoring → Write** if it may act: acknowledge an incident, leave the team a note, silence a monitor, check a
monitor again, run a maintenance window. Start with a test token in your [sandbox](../../README.md#start-here-your-sandbox):
it sees sample data only. Never commit a token — every file here reads it from the environment or asks for it.

```sh
export INFRANEST_TOKEN='123|in_test_…'
./check-connection.sh      # the token reaches the server, and what it reads
./add-to-claude-code.sh
```

## Tested against the sandbox

CI runs `check-connection.sh` against an InfraNest sandbox on every pull request (`scripts/sandbox-run.sh mcp`) and
checks that it connects and lists the sandbox.

## Five questions to start with

1. *Is anything down right now?* — one call covers every monitor, server, open incident and maintenance window.
2. *Why is web-01 alerting, and did anything change just before it started?* — the incident, the deploys before it,
   the server's metrics.
3. *Why doesn't mail.example.com resolve?* — the zone, its records, live DNS against what InfraNest holds, and
   changes made at the provider.
4. *Which domains and certificates expire in the next month?*
5. *Write last month's uptime report for the client tagged "acme".*

Claude and ChatGPT also offer four ready-made investigations in their prompt menu — *Investigate an incident*,
*What changed recently*, *Health check* and *Monthly uptime report* — and draw the status, uptime and server metrics
as charts. See [the MCP server](https://developers.infranest.io/ai-assistants) for every tool.
