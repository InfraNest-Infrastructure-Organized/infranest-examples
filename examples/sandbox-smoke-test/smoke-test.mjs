#!/usr/bin/env node
// A first run against your sandbox: reset it, change a DNS record and put it back. Node 18+, no packages.
//
//   INFRANEST_TOKEN  a test token made in your sandbox (it starts with in_test_ after the id)
//   INFRANEST_ORG    your sandbox organization's id
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

const org = env('INFRANEST_ORG')
console.log('Resetting the sandbox to its sample data…')
await infranest('POST', `/organizations/${org}/sandbox/reset`)

const zones = await infranest('GET', `/organizations/${org}/dns-zones`)
const zone = (zones.data ?? zones)[0].id
console.log(`Using zone ${zone}.`)

const { id: record } = await infranest('POST', `/organizations/${org}/dns-zones/${zone}/dns-records`,
  { type: 'TXT', name: 'smoke-test', value: 'hello from the examples', ttl: 300 }, `smoke-test-${Date.now()}`)
console.log(`Created TXT record ${record}.`)

const preview = await infranest('PUT', `/organizations/${org}/dns-zones/${zone}/dns-records/${record}?dry_run=1`, { value: 'changed by the examples' })
console.log('What changing it would do (dry run):', JSON.stringify(preview.changes, null, 2))

await infranest('PUT', `/organizations/${org}/dns-zones/${zone}/dns-records/${record}`, { value: 'changed by the examples' })
await infranest('DELETE', `/organizations/${org}/dns-zones/${zone}/dns-records/${record}`)
console.log('Changed and deleted it again. Everything works.')
