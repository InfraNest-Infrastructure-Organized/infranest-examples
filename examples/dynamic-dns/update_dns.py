#!/usr/bin/env python3
"""Keep one A (or AAAA) record pointing at this machine's public address. Python 3.8+, no packages.

INFRANEST_TOKEN  a token with DNS → Write
INFRANEST_ORG    your organization's id
ZONE_ID, RECORD_ID  the zone and the record to keep up to date
FAMILY           4 (default) or 6
DRY_RUN          1 to only show what would change
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


org, zone, record = env("INFRANEST_ORG"), env("ZONE_ID"), env("RECORD_ID")
lookup = "https://api64.ipify.org" if os.environ.get("FAMILY") == "6" else "https://api.ipify.org"
with urllib.request.urlopen(lookup, timeout=15) as answer:
    current = answer.read().decode().strip()

stored = infranest("GET", f"/organizations/{org}/dns-zones/{zone}/dns-records/{record}")["value"]
if current == stored:
    sys.exit(0)

if os.environ.get("DRY_RUN") == "1":
    preview = infranest("PUT", f"/organizations/{org}/dns-zones/{zone}/dns-records/{record}?dry_run=1", {"value": current, "ttl": 300})
    print(json.dumps(preview["changes"], indent=2))
else:
    infranest("PUT", f"/organizations/{org}/dns-zones/{zone}/dns-records/{record}", {"value": current, "ttl": 300})
    print(f"Updated from {stored} to {current}")
