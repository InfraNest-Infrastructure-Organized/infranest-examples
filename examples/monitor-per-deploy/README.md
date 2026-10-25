# A monitor for every deployed service

Make sure a new service is watched from the pipeline that deploys it: the monitor is created once, and running the
step again finds it instead of creating another. `pause-resume.sh` pauses a monitor around a deploy.

Docs: [Create a monitor when you deploy a new service](https://developers.infranest.io/recipes/monitor-after-a-deploy)

| File | Language |
|---|---|
| [`create-monitor.sh`](create-monitor.sh) | POSIX sh, curl, jq |
| [`create_monitor.py`](create_monitor.py) | Python 3.8+ |
| [`create-monitor.mjs`](create-monitor.mjs) | Node.js 18+ |
| [`pause-resume.sh`](pause-resume.sh) | POSIX sh: pause or resume one monitor |

**Token:** Monitoring → Write (`monitoring.write`).

```sh
export INFRANEST_TOKEN='…' INFRANEST_ORG=42
NAME='API health' TARGET=https://api.example.com/health ./create-monitor.sh   # prints the monitor's id
MONITOR_ID=1201 ./pause-resume.sh pause
```

## Tested against the sandbox

CI runs every version, twice, and pause and resume against an InfraNest sandbox on every pull request and once a week (`scripts/sandbox-run.sh monitor-per-deploy`), and checks that it did what it says. You can run the same check with a test token from your own sandbox:

```sh
INFRANEST_TOKEN='123|in_test_…' scripts/sandbox-run.sh monitor-per-deploy
```
