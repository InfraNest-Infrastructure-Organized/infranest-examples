#!/usr/bin/env node
// Keep one A (or AAAA) record pointing at this machine's public address. Node 18+, no packages.
//
//   INFRANEST_TOKEN  a token with DNS → Write
//   INFRANEST_ORG    your organization's id
//   ZONE_ID, RECORD_ID  the zone and the record to keep up to date
//   FAMILY           4 (default) or 6
//   ADDRESS          optional: use this address instead of looking it up (from your router, or for a test)
//   DRY_RUN          1 to only show what would change
const API = process.env.INFRANEST_API ?? 'https://api.infranest.io/api'
const TOKEN = process.env.INFRANEST_TOKEN
if (!TOKEN) { console.error('Set INFRANEST_TOKEN to an InfraNest API token'); process.exit(1) }

/** Call the InfraNest API and return the JSON answer (null for an empty one). Exits on a refusal, printing it. */
async function infranest (method, path, body, idempotencyKey) {
  const headers = { Authorization: `Bearer ${TOKEN}`, Accept: 'application/json' }
  if (body !== undefined) {
    headers['Content-Type'] = 'application/json'
    if (idempotencyKey) headers['Idempotency-Key'] = idempotencyKey
  }
  const answer = await fetch(API + path, { method, headers, body: body === undefined ? undefined : JSON.stringify(body) })
  const text = await answer.text()
  if (!answer.ok) { console.error(`${method} ${path} answered ${answer.status}: ${text}`); process.exit(1) }
  return text ? JSON.parse(text) : null
}

function env (name) {
  const value = process.env[name]
  if (!value) { console.error(`Set ${name}`); process.exit(1) }
  return value
}

const [org, zone, record] = [env('INFRANEST_ORG'), env('ZONE_ID'), env('RECORD_ID')]
const lookup = process.env.FAMILY === '6' ? 'https://api64.ipify.org' : 'https://api.ipify.org'
const current = process.env.ADDRESS || (await (await fetch(lookup)).text()).trim()

const { value: stored } = await infranest('GET', `/organizations/${org}/dns-zones/${zone}/dns-records/${record}`)
if (current === stored) process.exit(0)

if (process.env.DRY_RUN === '1') {
  const preview = await infranest('PUT', `/organizations/${org}/dns-zones/${zone}/dns-records/${record}?dry_run=1`, { value: current, ttl: 300 })
  console.log(JSON.stringify(preview.changes, null, 2))
} else {
  await infranest('PUT', `/organizations/${org}/dns-zones/${zone}/dns-records/${record}`, { value: current, ttl: 300 })
  console.log(`Updated from ${stored} to ${current}`)
}
