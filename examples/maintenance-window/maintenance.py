#!/usr/bin/env python3
"""Silence alerts while a deploy runs, and close the window when it is done. Python 3.8+, no packages.

  maintenance.py open    prints the new window's id
  maintenance.py close   closes the window in WINDOW_ID

INFRANEST_TOKEN  a token with Monitoring → Write
INFRANEST_ORG    your organization's id
CHECK_IDS        the monitors to silence, comma-separated (open)
NAME, MINUTES    what it is called (default Deploy) and how long at most (default 30) (open)
DEPLOY_ID        unique per deploy, e.g. your CI's pipeline id: a retried step opens one window
WINDOW_ID        the window to close (close)
"""
from datetime import datetime, timedelta, timezone
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
action = sys.argv[1] if len(sys.argv) > 1 else ""

if action == "open":
    now = datetime.now(timezone.utc).replace(microsecond=0)
    end = now + timedelta(minutes=int(os.environ.get("MINUTES", "30")))
    window = infranest("POST", f"/organizations/{org}/maintenance-windows", {
        "name": os.environ.get("NAME", "Deploy"),
        "starts_at": now.isoformat().replace("+00:00", "Z"),
        "ends_at": end.isoformat().replace("+00:00", "Z"),
        "suppress_alerts": True,
        "check_ids": [int(i) for i in env("CHECK_IDS").split(",")],
    }, idempotency_key=f"deploy-{os.environ.get('DEPLOY_ID', int(now.timestamp()))}")
    print(window["id"])
elif action == "close":
    window_id = env("WINDOW_ID")
    infranest("PATCH", f"/organizations/{org}/maintenance-windows/{window_id}/complete")
    print(f"Maintenance window {window_id} closed; alerts are back on.")
else:
    sys.exit("Usage: maintenance.py open|close")
