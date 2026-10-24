<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/infranest-logo-dark.svg">
    <img alt="InfraNest" src=".github/assets/infranest-logo-light.svg" width="300">
  </picture>
</p>

<h1 align="center">infranest-examples</h1>

<p align="center">
  <strong>Ready-to-run scripts for the InfraNest API.</strong><br>
  Copy one, set three variables, run it. Try them in your sandbox first.
</p>

<p align="center">
  <a href="https://github.com/InfraNest-Infrastructure-Organized/infranest-examples/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/InfraNest-Infrastructure-Organized/infranest-examples/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="Licence: Apache-2.0" src="https://img.shields.io/badge/licence-Apache--2.0-blue">
  <img alt="Needs: sh, curl, jq" src="https://img.shields.io/badge/needs-sh%2C%20curl%2C%20jq-lightgrey">
</p>

---

[InfraNest](https://infranest.io) keeps your domains, DNS, servers and monitoring in one place. Its API lets your
own scripts, deploy pipelines and AI tools do the same work. This repository has small, complete examples for the
jobs people automate most often: each one is a single shell script you can read in a minute and run as it is.

## Start here: your sandbox

Your sandbox is a free InfraNest organization with sample DNS zones, records and monitors. Nothing you do there
reaches a DNS provider, a cloud provider or the internet, so it is the safe place to try these scripts.

1. In InfraNest, open **My account → Developer** and select **Create a sandbox**.
2. While you are in the sandbox, create a token on the same page. It is a **test token**: it starts with
   `in_test_` and works only in your sandbox.
3. Run the smoke test:

   ```sh
   export INFRANEST_TOKEN='123|in_test_…'   # your test token
   export INFRANEST_ORG=42                   # your sandbox's id
   ./examples/sandbox-smoke-test/smoke-test.sh
   ```

It resets the sandbox, adds a DNS record, shows what changing it would do, changes it and deletes it again.
When that works, everything you need is set up.

## The examples

| Example | What it does | Token needs |
|---|---|---|
| [`sandbox-smoke-test`](examples/sandbox-smoke-test/smoke-test.sh) | A first run: reset the sandbox, then create, preview, change and delete a record | a sandbox test token |
| [`dynamic-dns`](examples/dynamic-dns/update-dns.sh) | Keep a record pointing at a machine whose public address changes | DNS → Write |
| [`acme-dns-01`](examples/acme-dns-01/) | Let's Encrypt certificates through InfraNest DNS, wildcards included (certbot hooks) | DNS → Write |
| [`maintenance-window`](examples/maintenance-window/) | Silence alerts during a deploy and close the window afterwards, even if it failed | Monitoring → Write |
| [`monitor-per-deploy`](examples/monitor-per-deploy/) | Make sure every new service has a monitor; pause one around a deploy | Monitoring → Write |
| [`watch-new-server`](examples/watch-new-server/watch-server.sh) | Turn on monitoring for a new server and check its website | Servers → Write, Monitoring → Write |
| [`audit-log-to-siem`](examples/audit-log-to-siem/export-audit-log.sh) | Write a day of the audit log as JSON lines for your log platform | Audit log → Read |

Every script starts with a comment that says what it does and which variables it reads. The DNS examples can
show what they would change first (`DRY_RUN=1`), and every script that creates something sends an
`Idempotency-Key`, so a retried run does not create it twice.

## What you need

- A POSIX shell (`sh`, `bash`, `zsh`), [`curl`](https://curl.se) 7.76 or newer, and [`jq`](https://jqlang.github.io/jq/).
- An InfraNest API token with only the scopes the example needs. Create one under **My account → Developer**.
- Your organization's id: it is under **Settings → Organization** in the app.

Every script reads the same three variables, plus its own (listed at the top of the script):

| Variable | What it is |
|---|---|
| `INFRANEST_TOKEN` | Your API token. Keep it in your CI's secret store, never in a repository. |
| `INFRANEST_ORG` | Your organization's id. |
| `INFRANEST_API` | Optional. The API address, `https://api.infranest.io/api` unless you set it. |

## Use at your own risk

These scripts are examples. They are meant to be read, understood and adapted to your situation, and they
**change real infrastructure** when you point them at a live organization: DNS records, monitors, maintenance
windows.

- **Read a script before you run it**, and run it in your sandbox before you run it anywhere else.
- **You are responsible** for what a script does with your token and to your infrastructure, and for keeping your
  tokens safe. Give each token only the scopes it needs.
- **Costs are yours.** What a script changes can cause costs at your providers. See
  [Responsibility and costs](https://developers.infranest.io/responsibility-and-costs).
- **No warranty.** The scripts are provided "as is", without warranty of any kind, under the
  [Apache License 2.0](LICENSE). InfraNest's support covers the InfraNest API and app, not changes you make to these
  scripts.
- Your use of InfraNest is governed by its [Terms of Service](https://infranest.io/terms).

## Kept in step with the API

Every pull request and a weekly job check each API call in these scripts against InfraNest's published API
description: the method, the path and every field a request sends. A renamed endpoint or field fails the check
here, before it fails in your pipeline. [ShellCheck](https://www.shellcheck.net) checks the scripts too.

## Links

- [Developer documentation](https://developers.infranest.io): getting started, tokens and scopes, errors
- [API reference](https://developers.infranest.io/reference)
- [Sandbox guide](https://developers.infranest.io/sandbox)
- [Help center](https://infranest.io/docs) and the article on [API tokens](https://infranest.io/docs/api-tokens)
- [Service status](https://status.infranest.io)
- [infranest-agent](https://github.com/InfraNest-Infrastructure-Organized/infranest-agent), the open-source
  monitoring agent for your servers

## Found a problem?

Open an [issue](https://github.com/InfraNest-Infrastructure-Organized/infranest-examples/issues) for a script that
does not work as described. Improvements and new examples are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

For a security issue in InfraNest itself, please do not open an issue: see [SECURITY.md](SECURITY.md).

## Licence

[Apache License 2.0](LICENSE).
