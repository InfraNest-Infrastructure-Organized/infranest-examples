# Maintenance window from a pipeline

Silence alerts while a deploy runs and close the window afterwards, even when the deploy failed.

Docs: [Open a maintenance window from your deploy pipeline](https://developers.infranest.io/recipes/maintenance-window-from-a-pipeline)

| File | Language |
|---|---|
| [`maintenance.sh`](maintenance.sh) | POSIX sh, curl, jq |
| [`maintenance.py`](maintenance.py) | Python 3.8+ |
| [`maintenance.mjs`](maintenance.mjs) | Node.js 18+ |
| [`Maintenance.ps1`](Maintenance.ps1) | PowerShell 7 (5.1 works too) |
| [`github-actions-example.yml`](github-actions-example.yml) | A GitHub Actions job that opens, deploys and always closes |

**Token:** Monitoring → Write (`monitoring.write`).

```sh
export INFRANEST_TOKEN='…' INFRANEST_ORG=42 CHECK_IDS=1201,1202 DEPLOY_ID="$CI_PIPELINE_ID"
WINDOW_ID=$(./maintenance.sh open)
./deploy.sh || true
WINDOW_ID=$WINDOW_ID ./maintenance.sh close
```

## Tested against the sandbox

CI runs every version against an InfraNest sandbox on every pull request and once a week (`scripts/sandbox-run.sh maintenance-window`), and checks that it did what it says. You can run the same check with a test token from your own sandbox:

```sh
INFRANEST_TOKEN='123|in_test_…' scripts/sandbox-run.sh maintenance-window
```
