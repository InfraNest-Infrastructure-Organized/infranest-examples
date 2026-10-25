# Audit log to your SIEM

Write one day of your organization's audit log as JSON lines, the format Filebeat, Vector and the Splunk forwarder
read. Run it daily, shortly after midnight UTC.

Docs: [Copy the audit log into your SIEM](https://developers.infranest.io/recipes/audit-log-to-a-siem)

| File | Language |
|---|---|
| [`export-audit-log.sh`](export-audit-log.sh) | POSIX sh, curl, jq |

**Token:** Audit log → Read (`audit-log.read`), nothing else.

```sh
export INFRANEST_TOKEN='…' INFRANEST_ORG=42
OUT_DIR=/var/log/infranest ./export-audit-log.sh   # writes audit-YYYY-MM-DD.jsonl for yesterday
```

## Tested against the sandbox

CI runs it, for today, against an InfraNest sandbox on every pull request and once a week (`scripts/sandbox-run.sh audit-log-to-siem`), and checks that it did what it says. You can run the same check with a test token from your own sandbox:

```sh
INFRANEST_TOKEN='123|in_test_…' scripts/sandbox-run.sh audit-log-to-siem
```
