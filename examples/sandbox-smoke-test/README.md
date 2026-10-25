# Sandbox smoke test

A first run against your sandbox: it resets the sandbox, adds a DNS record, shows what changing it would do, changes it
and deletes it again. When it passes, your token, your sandbox id and your tools are set up.

Docs: [Sandbox](https://developers.infranest.io/sandbox)

| File | Language |
|---|---|
| [`smoke-test.sh`](smoke-test.sh) | POSIX sh, curl, jq |
| [`smoke_test.py`](smoke_test.py) | Python 3.8+ |
| [`smoke-test.mjs`](smoke-test.mjs) | Node.js 18+ |

**Token:** a test token made in your sandbox (it starts with `in_test_` after the id).

```sh
export INFRANEST_TOKEN='123|in_test_…'
export INFRANEST_ORG=42   # your sandbox's id
./smoke-test.sh
```

## Tested against the sandbox

CI runs every version against an InfraNest sandbox on every pull request and once a week (`scripts/sandbox-run.sh sandbox-smoke-test`), and checks that it did what it says. You can run the same check with a test token from your own sandbox:

```sh
INFRANEST_TOKEN='123|in_test_…' scripts/sandbox-run.sh sandbox-smoke-test
```
