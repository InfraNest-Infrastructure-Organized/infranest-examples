#!/usr/bin/env node
// Make sure a new service is watched: create its monitor, once. Node 18+, no packages.
//
//   INFRANEST_TOKEN  a token with Monitoring → Write
//   INFRANEST_ORG    your organization's id
//   NAME, TARGET     e.g. "API health" and https://api.example.com/health
//   TYPE             http (default), port, ssl, dns, keyword, redirect, ping or api
//   INTERVAL         seconds between checks: 30, 60, 120, 300 (default), 600, 900, 1800 or 3600
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

const [org, name, target] = [env('INFRANEST_ORG'), env('NAME'), env('TARGET')]

const monitors = await infranest('GET', `/organizations/${org}/monitoring-checks`)
const existing = (monitors.data ?? monitors).find(m => m.target === target)
if (existing) {
  console.log(existing.id)
  process.exit(0)
}

const monitor = await infranest('POST', `/organizations/${org}/monitoring-checks`, {
  name,
  type: process.env.TYPE ?? 'http',
  target,
  interval_seconds: Number(process.env.INTERVAL ?? 300),
}, `monitor-${target}`)
console.log(monitor.id)
