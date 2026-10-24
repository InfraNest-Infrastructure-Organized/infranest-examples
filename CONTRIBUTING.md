# Contributing

Thanks for helping. A fix for a script that does not work as described, a clearer comment, or a new example for a
common job are all welcome.

## What makes a good example

- **One job, one script**, readable in a minute. A comment at the top says what it does and every variable it reads.
- **No dependencies.** Shell scripts use POSIX `sh`, `curl` and `jq`; Python, JavaScript and PowerShell versions use
  only what ships with Python 3.8+, Node.js 18+ and PowerShell 7. Each script is one file.
- **Calls the API through the language's helper**, with the body written inline, so CI can check every call against
  the API description:
  - sh: `infranest METHOD "/path" "$body"`, the body built by `body=$(jq -n '{…}')`
  - Python: `infranest("METHOD", f"/path", {"field": …})`
  - JavaScript: ``infranest('METHOD', `/path`, { field: … })``
  - PowerShell: `Invoke-InfraNest -Method METHOD -Path "/path" -Body @{ field = … }`
- **The same behaviour in every language.** A new language version of an example does exactly what the shell one does.
- **Safe to run twice.** Look before you create, and send an `Idempotency-Key` on every create.
- **Least privilege.** Say which token scopes it needs, and need as few as possible.
- **Sample values only:** `example.com`, `192.0.2.x`, `2001:db8::`. Never a real token, address or domain.

## Before you open a pull request

```sh
shellcheck -s sh examples/*/*.sh
python3 scripts/check-requests.py   # downloads the API description; or pass a local openapi.json
```

Both run in CI as well. Try the script in your InfraNest sandbox, and say in the pull request that you did.
