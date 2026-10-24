#!/usr/bin/env python3
"""A first run against your sandbox: reset it, change a DNS record and put it back. Python 3.8+, no packages.

INFRANEST_TOKEN  a test token made in your sandbox (it starts with in_test_ after the id)
INFRANEST_ORG    your sandbox organization's id
"""
import time
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


org = env("INFRANEST_ORG")
print("Resetting the sandbox to its sample data…")
infranest("POST", f"/organizations/{org}/sandbox/reset")

zones = infranest("GET", f"/organizations/{org}/dns-zones")
zone = (zones.get("data", zones) if isinstance(zones, dict) else zones)[0]["id"]
print(f"Using zone {zone}.")

record = infranest("POST", f"/organizations/{org}/dns-zones/{zone}/dns-records",
                   {"type": "TXT", "name": "smoke-test", "value": "hello from the examples", "ttl": 300},
                   idempotency_key=f"smoke-test-{int(time.time())}")["id"]
print(f"Created TXT record {record}.")

preview = infranest("PUT", f"/organizations/{org}/dns-zones/{zone}/dns-records/{record}?dry_run=1", {"value": "changed by the examples"})
print("What changing it would do (dry run):", json.dumps(preview["changes"], indent=2))

infranest("PUT", f"/organizations/{org}/dns-zones/{zone}/dns-records/{record}", {"value": "changed by the examples"})
infranest("DELETE", f"/organizations/{org}/dns-zones/{zone}/dns-records/{record}")
print("Changed and deleted it again. Everything works.")
