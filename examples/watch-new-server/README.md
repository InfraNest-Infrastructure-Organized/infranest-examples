# Start watching a new server

Turn on monitoring for a server you just created at your cloud provider, and add a check on its website, so a new
machine is watched from its first hour.

Docs: [Start watching a new server](https://developers.infranest.io/recipes/watch-a-new-server)

| File | Language |
|---|---|
| [`watch-server.sh`](watch-server.sh) | POSIX sh, curl, jq |

**Token:** Servers → Write (`cloud.write`) and Monitoring → Write (`monitoring.write`).

```sh
export INFRANEST_TOKEN='…' INFRANEST_ORG=42
SERVER_NAME=web-03 WEBSITE_URL=https://web-03.example.com ./watch-server.sh
```

For CPU, memory and disk metrics, install the agent as well: see [`agent-install`](../agent-install/).

## Tested against the sandbox

CI runs it, on the sandbox's sample server `web-01`, against an InfraNest sandbox on every pull request and once a week (`scripts/sandbox-run.sh watch-new-server`), and checks that it did what it says. You can run the same check with a test token from your own sandbox:

```sh
INFRANEST_TOKEN='123|in_test_…' scripts/sandbox-run.sh watch-new-server
```
