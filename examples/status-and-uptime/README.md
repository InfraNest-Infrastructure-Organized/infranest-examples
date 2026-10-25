# Status, uptime and history

Is everything up right now, what was a monitor's uptime last month, and what happened hour by hour: each answered in
one call, for a dashboard, a chat bot or a weekly report.

Docs: [Status, uptime and history](https://developers.infranest.io/recipes/status-and-uptime)

| File | What it does |
|---|---|
| [`status.sh`](status.sh) | Every monitor and server right now, open incidents and running maintenance, and a traffic light. `STRICT=1` exits 1 when the light is not green |
| [`uptime.sh`](uptime.sh) | One monitor's uptime and response times for a period (`PERIOD`, or a calendar `MONTH`), hour by hour with `HOURLY=1`; without `MONITOR_ID`, the monthly uptime report for every monitor |

Both are POSIX sh with curl and jq.

**Token:** Monitoring → Read (`monitoring.read`). Add Servers → Read (`cloud.read`) to include your servers in
`status.sh`; without it they are left out.

```sh
export INFRANEST_TOKEN='…' INFRANEST_ORG=42
./status.sh                          # add TAG=7 for one customer's or one team's monitors and servers
MONITOR_ID=3 PERIOD=30d HOURLY=1 ./uptime.sh
MONTH=2026-01 ./uptime.sh            # every monitor, one calendar month
```

The sandbox's sample monitors are never actually checked, so there they answer "no data".

## Tested against the sandbox

CI runs both scripts against an InfraNest sandbox on every pull request and once a week (`scripts/sandbox-run.sh status-and-uptime`), and checks that it did what it says. You can run the same check with a test token from your own sandbox:

```sh
INFRANEST_TOKEN='123|in_test_…' scripts/sandbox-run.sh status-and-uptime
```
