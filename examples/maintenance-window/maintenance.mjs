#!/usr/bin/env node
// Silence alerts while a deploy runs, and close the window when it is done. Node 18+, no packages.
//
//   maintenance.mjs open    prints the new window's id
//   maintenance.mjs close   closes the window in WINDOW_ID
//
//   INFRANEST_TOKEN  a token with Monitoring → Write
//   INFRANEST_ORG    your organization's id
//   CHECK_IDS        the monitors to silence, comma-separated (open)
//   NAME, MINUTES    what it is called (default Deploy) and how long at most (default 30) (open)
//   DEPLOY_ID        unique per deploy, e.g. your CI's pipeline id: a retried step opens one window
//   WINDOW_ID        the window to close (close)
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
const iso = (date) => date.toISOString().replace(/\.\d{3}Z$/, 'Z')

switch (process.argv[2]) {
  case 'open': {
    const now = new Date()
    const end = new Date(now.getTime() + Number(process.env.MINUTES ?? 30) * 60_000)
    const window = await infranest('POST', `/organizations/${org}/maintenance-windows`, {
      name: process.env.NAME ?? 'Deploy',
      starts_at: iso(now),
      ends_at: iso(end),
      suppress_alerts: true,
      check_ids: env('CHECK_IDS').split(',').map(Number),
    }, `deploy-${process.env.DEPLOY_ID ?? now.getTime()}`)
    console.log(window.id)
    break
  }
  case 'close': {
    const windowId = env('WINDOW_ID')
    await infranest('PATCH', `/organizations/${org}/maintenance-windows/${windowId}/complete`)
    console.log(`Maintenance window ${windowId} closed; alerts are back on.`)
    break
  }
  default:
    console.error('Usage: maintenance.mjs open|close')
    process.exit(2)
}
