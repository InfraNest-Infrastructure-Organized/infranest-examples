<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/infranest-logo-dark.svg">
    <img alt="InfraNest" src=".github/assets/infranest-logo-light.svg" width="300">
  </picture>
</p>

<h1 align="center">infranest-examples</h1>

<p align="center">
  <strong>Ready-to-run scripts for the InfraNest API.</strong><br>
  In shell, Python, JavaScript and PowerShell. Copy one, set three variables, run it. Try them in your sandbox first.
</p>

<p align="center">
  <a href="https://github.com/InfraNest-Infrastructure-Organized/infranest-examples/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/InfraNest-Infrastructure-Organized/infranest-examples/actions/workflows/ci.yml/badge.svg"></a>
  <img alt="Licence: Apache-2.0" src="https://img.shields.io/badge/licence-Apache--2.0-blue">
  <img alt="No dependencies" src="https://img.shields.io/badge/dependencies-none-brightgreen">
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

| Example | What it does | Token needs | In | Docs |
|---|---|---|---|---|
| [`sandbox-smoke-test`](examples/sandbox-smoke-test/) | A first run: reset the sandbox, then create, preview, change and delete a record | a sandbox test token | [sh](examples/sandbox-smoke-test/smoke-test.sh) · [Python](examples/sandbox-smoke-test/smoke_test.py) · [JS](examples/sandbox-smoke-test/smoke-test.mjs) | [Sandbox](https://developers.infranest.io/sandbox) |
| [`quickstart`](examples/quickstart/) | The developer site's quickstart: find the sandbox, read its zones, dry-run, create and undo a record — checking each answer | a sandbox test token, DNS → Read and Write | [sh](examples/quickstart/quickstart.sh) | [Quickstart](https://developers.infranest.io/quickstart) |
| [`dynamic-dns`](examples/dynamic-dns/) | Keep a record pointing at a machine whose public address changes | DNS → Write | [sh](examples/dynamic-dns/update-dns.sh) · [Python](examples/dynamic-dns/update_dns.py) · [JS](examples/dynamic-dns/update-dns.mjs) · [PowerShell](examples/dynamic-dns/Update-Dns.ps1) | [Dynamic DNS from a script](https://developers.infranest.io/recipes/dynamic-dns-from-a-script) |
| [`acme-dns-01`](examples/acme-dns-01/) | Let's Encrypt certificates through InfraNest DNS, wildcards included (certbot hooks) | DNS → Write | [sh](examples/acme-dns-01/) | [Let's Encrypt with InfraNest DNS](https://developers.infranest.io/recipes/acme-dns-01) |
| [`maintenance-window`](examples/maintenance-window/) | Silence alerts during a deploy and close the window afterwards, even if it failed | Monitoring → Write | [sh](examples/maintenance-window/maintenance.sh) · [Python](examples/maintenance-window/maintenance.py) · [JS](examples/maintenance-window/maintenance.mjs) · [PowerShell](examples/maintenance-window/Maintenance.ps1) · [GitHub Actions](examples/maintenance-window/github-actions-example.yml) | [Maintenance window from a pipeline](https://developers.infranest.io/recipes/maintenance-window-from-a-pipeline) |
| [`monitor-per-deploy`](examples/monitor-per-deploy/) | Make sure every new service has a monitor; pause one around a deploy | Monitoring → Write | [sh](examples/monitor-per-deploy/) · [Python](examples/monitor-per-deploy/create_monitor.py) · [JS](examples/monitor-per-deploy/create-monitor.mjs) | [Monitor after a deploy](https://developers.infranest.io/recipes/monitor-after-a-deploy) |
| [`watch-new-server`](examples/watch-new-server/) | Turn on monitoring for a new server and check its website | Servers → Write, Monitoring → Write | [sh](examples/watch-new-server/watch-server.sh) | [Watch a new server](https://developers.infranest.io/recipes/watch-a-new-server) |
| [`status-and-uptime`](examples/status-and-uptime/) | Is everything up right now, a monitor's uptime for a period or a month, and hour-by-hour results | Monitoring → Read (Servers → Read for servers) | [sh](examples/status-and-uptime/) | [Status, uptime and history](https://developers.infranest.io/recipes/status-and-uptime) |
| [`audit-log-to-siem`](examples/audit-log-to-siem/) | Write a day of the audit log as JSON lines for your log platform | Audit log → Read | [sh](examples/audit-log-to-siem/export-audit-log.sh) | [Audit log to a SIEM](https://developers.infranest.io/recipes/audit-log-to-a-siem) |
| [`verify-webhook`](examples/verify-webhook/) | Check that a webhook delivery really came from InfraNest (the signature, and its age) | none — the endpoint's signing secret | [JS](examples/verify-webhook/verify.mjs) · [Python](examples/verify-webhook/verify.py) · [PHP](examples/verify-webhook/verify.php) · [Go](examples/verify-webhook/verify.go) · [PowerShell](examples/verify-webhook/Verify-Webhook.ps1) · [sh](examples/verify-webhook/verify.sh) | [Webhooks](https://developers.infranest.io/webhooks) |
| [`agent-install`](examples/agent-install/) | Install the server agent on many Linux and Windows servers: an Ansible role and a cloud-init file | a server token per server (no API token) | [Ansible](examples/agent-install/roles/infranest_agent/) · [cloud-init](examples/agent-install/cloud-init.yaml) | [Install the agent on many servers](https://developers.infranest.io/agent/install-on-many-servers) |

Every version does the same thing, and every script starts with a comment that says what it does and which
variables it reads. The DNS examples can
show what they would change first (`DRY_RUN=1`), and every script that creates something sends an
`Idempotency-Key`, so a retried run does not create it twice.

## What you need

- For the shell scripts: a POSIX shell (`sh`, `bash`, `zsh`), [`curl`](https://curl.se) 7.76 or newer, and
  [`jq`](https://jqlang.github.io/jq/). For the others: Python 3.8+, Node.js 18+, or PowerShell 7 (5.1 works
  too). None of them needs a package: each script is one file.
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

Every pull request, every change to `main` and a weekly job check these scripts in two ways:

- **Against the API description.** Each API call, in every language, is checked against InfraNest's published API
  description: the method, the path and every field a request sends. A renamed endpoint or field fails the check
  here, before it fails in your pipeline. [ShellCheck](https://www.shellcheck.net) checks the shell scripts, and the
  Python, JavaScript and PowerShell versions are checked to parse.
- **Against a real sandbox.** Every example, in every language, is run against an InfraNest sandbox the way you
  would run it, and checked to do what it says; what it creates is removed again and the sandbox is reset at the
  end. [`scripts/sandbox-run.sh`](scripts/sandbox-run.sh) does it, and you can run it yourself with a test token
  from your own sandbox: `INFRANEST_TOKEN='123|in_test_…' scripts/sandbox-run.sh`. It refuses any token that is not
  a test token. The agent example installs software on servers, so it is linted and run in Ansible's check mode
  instead.

## Links

- [Developer documentation](https://developers.infranest.io): getting started, tokens and scopes, errors
- [API reference](https://developers.infranest.io/reference)
- [Sandbox guide](https://developers.infranest.io/sandbox)
- [Help center](https://infranest.io/docs) and the article on [API tokens](https://infranest.io/docs/api-tokens)
- [Service status](https://status.infranest.io)
- [infranest-agent](https://github.com/InfraNest-Infrastructure-Organized/infranest-agent), the open-source
  monitoring agent for your servers
- [infranest-mcp](https://github.com/InfraNest-Infrastructure-Organized/infranest-mcp), the MCP server: ask your AI assistant what is down, where a hostname points, or what
  expires soon

## Found a problem?

Open an [issue](https://github.com/InfraNest-Infrastructure-Organized/infranest-examples/issues) for a script that
does not work as described. Improvements and new examples are welcome; see [CONTRIBUTING.md](CONTRIBUTING.md).

For a security issue in InfraNest itself, please do not open an issue: see [SECURITY.md](SECURITY.md).

## Licence

[Apache License 2.0](LICENSE).
