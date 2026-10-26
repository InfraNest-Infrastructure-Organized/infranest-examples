# Dynamic IP

Keep DNS records pointing at a connection whose public address changes: a home line, an office, a server behind
NAT. Unlike [`dynamic-dns`](../dynamic-dns/), which rewrites one record itself, this reports the address to an
InfraNest **Dynamic IP** source. InfraNest then updates every record the source keeps, keeps a history, alerts you
when the address changes and sends a `dynamic_ip.changed` event to your automations and webhooks. A source can
also keep a firewall rule open to that address only.

Create the source in InfraNest under **Automations → Dynamic IPs**, attach the records it should keep, and copy its
public id and update password.

Docs: [Keep a name on a changing address with Dynamic IP](https://developers.infranest.io/recipes/dynamic-ip)

| File | Use it when | Credential |
|---|---|---|
| [`dyn-update.sh`](dyn-update.sh) | It runs on the connection itself (cron, a Raspberry Pi) | the source's update password |
| [`ddclient.conf`](ddclient.conf) | You already run `ddclient`, or your router speaks dyndns2 | the source's update password |
| [`systemd/`](systemd/) | You want `dyn-update.sh` every 5 minutes without cron | the source's update password |
| [`set-address.sh`](set-address.sh) | Something else knows the new address: a deploy step, a cloud hook | an API token, Monitoring → Write |

## The update endpoint

```sh
export DYN_USER='dyn_…' DYN_PASSWORD='…'   # the source's public id and update password
./dyn-update.sh                             # good 198.51.100.7  /  nochg 198.51.100.7
ADDRESS=198.51.100.7 ./dyn-update.sh        # report this address instead of the one you call from
```

It needs no API token: the update password can report this one source's address and do nothing else. It is sent
in Basic auth, never in the URL. `badauth` (wrong id or password) and `nohost` (no usable address) exit non-zero.

With systemd: copy `dyn-update.sh` to `/usr/local/bin/`, put `DYN_USER=…` and `DYN_PASSWORD=…` in
`/etc/infranest-dyn.env` (`chmod 600`), copy both units to `/etc/systemd/system/` and run
`systemctl enable --now infranest-dyn.timer`.

## With an API token

```sh
export INFRANEST_TOKEN='…' INFRANEST_ORG=42 DYNAMIC_IP_ID=7
ADDRESS=198.51.100.7 ./set-address.sh   # Changed to 198.51.100.7; 2 record(s) updated
```

Silent when the address did not change, so cron mails only real changes. Leave `ADDRESS` out to use this
machine's public address; set `ADDRESS6` for IPv6.

A source that keeps a **firewall rule** open refuses token writes (`403 not_token_writable`): a new address there
changes who can reach the server. Use `dyn-update.sh` for those, or change them in the app.

## Tested against the sandbox

Every sandbox has a sample source, **Office**, keeping `office.sandbox-{id}.example`. CI sets its address with
`set-address.sh` and checks that the record followed and that a second run changes nothing, then checks that
`dyn-update.sh` fails loudly on a wrong password (`scripts/sandbox-run.sh dynamic-ip`). The update password itself
is shown only in the app, so a successful `dyn-update.sh` is something to try from your own sandbox:

```sh
INFRANEST_TOKEN='123|in_test_…' scripts/sandbox-run.sh dynamic-ip
```
