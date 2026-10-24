# Contributing

Thanks for helping. A fix for a script that does not work as described, a clearer comment, or a new example for a
common job are all welcome.

## What makes a good example

- **One job, one script**, readable in a minute. A comment at the top says what it does and every variable it reads.
- **POSIX `sh`, `curl` and `jq` only.** No other dependencies, so it runs on any CI runner and any server.
- **Calls the API through the `infranest` helper** (`infranest METHOD "/path" "$body"`), with bodies built by
  `jq -n '{…}'`. That is what lets CI check every call against the API description.
- **Safe to run twice.** Look before you create, and send an `Idempotency-Key` on every create.
- **Least privilege.** Say which token scopes it needs, and need as few as possible.
- **Sample values only:** `example.com`, `192.0.2.x`, `2001:db8::`. Never a real token, address or domain.

## Before you open a pull request

```sh
shellcheck -s sh examples/*/*.sh
python3 scripts/check-requests.py
```

Both run in CI as well. Try the script in your InfraNest sandbox, and say in the pull request that you did.
