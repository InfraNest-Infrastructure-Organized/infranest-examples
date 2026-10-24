#!/usr/bin/env python3
"""Make sure a new service is watched: create its monitor, once. Python 3.8+, no packages.

INFRANEST_TOKEN  a token with Monitoring → Write
INFRANEST_ORG    your organization's id
NAME, TARGET     e.g. "API health" and https://api.example.com/health
TYPE             http (default), port, ssl, dns, keyword, redirect, ping or api
INTERVAL         seconds between checks: 30, 60, 120, 300 (default), 600, 900, 1800 or 3600
"""
import json
import os
import sys
import urllib.error
import urllib.request

API = os.environ.get("INFRANEST_API", "https://api.infranest.io/api")
TOKEN = os.environ.get("INFRANEST_TOKEN") or sys.exit("Set INFRANEST_TOKEN to an InfraNest API token")


def infranest(method, path, body=None, idempotency_key=None):
    """Call the InfraNest API and return the JSON answer (None for an empty one). Exits on a refusal, printing it."""
    headers = {"Authorization": f"Bearer {TOKEN}", "Accept": "application/json"}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
        if idempotency_key:
            headers["Idempotency-Key"] = idempotency_key
    request = urllib.request.Request(API + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=30) as answer:
            text = answer.read().decode()
            return json.loads(text) if text else None
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {path} answered {error.code}: {error.read().decode()}")


def env(name):
    return os.environ.get(name) or sys.exit(f"Set {name}")


org, name, target = env("INFRANEST_ORG"), env("NAME"), env("TARGET")

monitors = infranest("GET", f"/organizations/{org}/monitoring-checks")
existing = [m for m in (monitors.get("data", monitors) if isinstance(monitors, dict) else monitors) if m.get("target") == target]
if existing:
    print(existing[0]["id"])
    sys.exit(0)

monitor = infranest("POST", f"/organizations/{org}/monitoring-checks", {
    "name": name,
    "type": os.environ.get("TYPE", "http"),
    "target": target,
    "interval_seconds": int(os.environ.get("INTERVAL", "300")),
}, idempotency_key=f"monitor-{target}")
print(monitor["id"])
