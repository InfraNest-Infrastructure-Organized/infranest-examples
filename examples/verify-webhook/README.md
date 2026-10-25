# Verify a webhook

Check that a request to your webhook receiver really came from InfraNest, before acting on it. Each file holds the
same function — the one on the developer site's [Webhooks](https://developers.infranest.io/webhooks#verify-the-signature)
page — plus a few lines that let you try it from the command line.

| File | Language | The function |
|---|---|---|
| [`verify.mjs`](verify.mjs) | Node.js 18+ | `verifyInfraNest(rawBody, headers, secret)` |
| [`verify.py`](verify.py) | Python 3.8+ | `verify_infranest(raw_body, headers, secret)` |
| [`verify.php`](verify.php) | PHP 8 | `verifyInfraNest($rawBody, $timestamp, $signature, $secret)` |
| [`verify.go`](verify.go) | Go | `VerifyInfraNest(rawBody, timestamp, signature, secret)` |
| [`Verify-Webhook.ps1`](Verify-Webhook.ps1) | PowerShell 7 | `Test-InfraNestSignature` |
| [`verify.sh`](verify.sh) | POSIX sh, openssl | the whole script |

**Secret:** the endpoint's signing secret (`whsec_…`), shown once when you save the endpoint under
**Integrations → Custom webhook**. Read it from `INFRANEST_WEBHOOK_SECRET`.

## How InfraNest signs a delivery

`X-InfraNest-Signature-V2` is `sha256=` and the hex HMAC-SHA256, with the signing secret, of
`"<X-InfraNest-Timestamp>.<raw body>"`. Every request carries it: a test delivery, a subscribed event and an
event sent by an automation. Refuse a timestamp more than 300 seconds from your clock, so a captured request
cannot be replayed.

The older `X-InfraNest-Signature` header is deprecated and sent until 30 April 2027. These verifiers ignore it.
See the [changelog](https://developers.infranest.io/changelog).

Use the body exactly as it arrived, before parsing it: re-encoding JSON changes the bytes. Compare in constant time.

```sh
export INFRANEST_WEBHOOK_SECRET='whsec_…'
node verify.mjs body.json "$TIMESTAMP" "$SIGNATURE" && echo genuine
```

## Tested

`test.sh` signs deliveries the way InfraNest does and runs every version against them: a timestamped
delivery accepted; the deprecated body-only form, a tampered body, a stale timestamp and another secret
refused. CI runs it on every pull request.

```sh
sh test.sh
```
