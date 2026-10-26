# Dynamic DNS from a script

Keep one A (or AAAA) record pointing at a machine whose public address changes, for example a Raspberry Pi at home.
The record is only changed when the address really changed, and `DRY_RUN=1` shows what would change first.

> **Consider [`dynamic-ip`](../dynamic-ip/) first.** It reports the address to an InfraNest Dynamic IP source, which
> keeps every record it holds, with a history, a change alert and an event, and it works from a router or `ddclient`
> with no API token. This example is for one record you want to rewrite yourself.

Docs: [Update DNS from a script when your IP changes](https://developers.infranest.io/recipes/dynamic-dns-from-a-script)

| File | Language |
|---|---|
| [`update-dns.sh`](update-dns.sh) | POSIX sh, curl, jq |
| [`update_dns.py`](update_dns.py) | Python 3.8+ |
| [`update-dns.mjs`](update-dns.mjs) | Node.js 18+ |
| [`Update-Dns.ps1`](Update-Dns.ps1) | PowerShell 7 (5.1 works too) |

**Token:** DNS → Write (`dns.write`), nothing else.

```sh
export INFRANEST_TOKEN='…' INFRANEST_ORG=42 ZONE_ID=318 RECORD_ID=9021
DRY_RUN=1 ./update-dns.sh   # see what would change
./update-dns.sh             # then run it every five minutes from cron
```

Set `ADDRESS` to use an address you already know (from your router, or for a test) instead of looking it up.

## Tested against the sandbox

CI runs every version against an InfraNest sandbox on every pull request and once a week (`scripts/sandbox-run.sh dynamic-dns`), and checks that it did what it says. You can run the same check with a test token from your own sandbox:

```sh
INFRANEST_TOKEN='123|in_test_…' scripts/sandbox-run.sh dynamic-dns
```
