# Let's Encrypt with InfraNest DNS (DNS-01)

Certbot hooks that prove you own a domain with a TXT record in InfraNest DNS, so you get certificates, wildcards
included, without opening a port.

Docs: [Let's Encrypt with InfraNest DNS](https://developers.infranest.io/recipes/acme-dns-01)

| File | What it is |
|---|---|
| [`auth-hook.sh`](auth-hook.sh) | `--manual-auth-hook`: adds the `_acme-challenge` TXT record |
| [`cleanup-hook.sh`](cleanup-hook.sh) | `--manual-cleanup-hook`: removes it again |

**Token:** DNS → Write (`dns.write`), nothing else.

```sh
export INFRANEST_TOKEN='…' INFRANEST_ORG=42 ZONE_ID=318
certbot certonly --manual --preferred-challenges dns \
  --manual-auth-hook ./auth-hook.sh --manual-cleanup-hook ./cleanup-hook.sh \
  -d example.com -d '*.example.com'
```

## Tested against the sandbox

CI runs both hooks, for the zone itself and for a subdomain, against an InfraNest sandbox on every pull request and once a week (`scripts/sandbox-run.sh acme-dns-01`), and checks that it did what it says. You can run the same check with a test token from your own sandbox:

```sh
INFRANEST_TOKEN='123|in_test_…' scripts/sandbox-run.sh acme-dns-01
```
