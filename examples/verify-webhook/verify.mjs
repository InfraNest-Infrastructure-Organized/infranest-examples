// Verify that a webhook delivery came from InfraNest. https://developers.infranest.io/webhooks#verify-the-signature
//
//   node verify.mjs BODY_FILE TIMESTAMP SIGNATURE     (TIMESTAMP '' when the header was absent)
//   INFRANEST_WEBHOOK_SECRET   the endpoint's signing secret (whsec_…)
// Exits 0 for a genuine delivery, 1 otherwise. Use verifyInfraNest() in your own receiver.
import crypto from 'node:crypto'
import { readFileSync } from 'node:fs'

// rawBody: the request body as a string or Buffer, before JSON.parse.
export function verifyInfraNest(rawBody, headers, secret, toleranceSeconds = 300) {
  const signature = headers['x-infranest-signature'] ?? ''
  const timestamp = headers['x-infranest-timestamp']
  let signed = Buffer.from(rawBody)
  if (timestamp !== undefined) {
    if (!/^\d+$/.test(timestamp) || Math.abs(Date.now() / 1000 - Number(timestamp)) > toleranceSeconds) return false
    signed = Buffer.concat([Buffer.from(`${timestamp}.`), signed])
  }
  const expected = 'sha256=' + crypto.createHmac('sha256', secret).update(signed).digest('hex')
  const a = Buffer.from(expected)
  const b = Buffer.from(signature)
  return a.length === b.length && crypto.timingSafeEqual(a, b)
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const [bodyFile, timestamp, signature] = process.argv.slice(2)
  const headers = { 'x-infranest-signature': signature }
  if (timestamp) headers['x-infranest-timestamp'] = timestamp
  process.exit(verifyInfraNest(readFileSync(bodyFile), headers, process.env.INFRANEST_WEBHOOK_SECRET ?? '') ? 0 : 1)
}
