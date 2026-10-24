#!/usr/bin/env python3
"""Check every API call in examples/ against InfraNest's published API description.

Each example calls the API through one helper, `infranest METHOD "/path" ["$body"]`, so the calls can be read
reliably: the method and path must be a public operation, and every field a request body sends (the keys of the
`jq -n '{...}'` that builds it) must be one that operation documents. A renamed endpoint or field fails here
instead of in somebody's deploy pipeline.

Usage: check-requests.py [openapi.json]   (default: download https://developers.infranest.io/openapi.json)
Exit 0 when everything matches, or when the description cannot be fetched (a warning, so a docs outage does not
block this repository); exit 1 on a mismatch.
"""
import json
import pathlib
import re
import sys
import urllib.request

URL = "https://developers.infranest.io/openapi.json"
CALL = re.compile(r'infranest\s+(GET|POST|PUT|PATCH|DELETE)\s+"([^"]+)"(?:\s+"\$(\w+)")?')
JQ_BODY = re.compile(r"""(\w+)=\$\(jq\s.*?'(\{.*?\})'\)""", re.S)
KEY = re.compile(r"[{,]\s*([a-z_]+)\s*:")
ASSIGN = re.compile(r'^\s*([A-Z_]+)="(/[^"]*)"', re.M)


def expand(path, assignments):
    """Expand a leading $NAME the script assigned (ORG="/organizations/$INFRANEST_ORG"), repeatedly."""
    for _ in range(5):
        match = re.match(r"\$(\w+)", path)
        if not match or match.group(1) not in assignments:
            break
        path = assignments[match.group(1)] + path[match.end():]
    return path


def load_spec():
    if len(sys.argv) > 1:
        return json.loads(pathlib.Path(sys.argv[1]).read_text())
    try:
        with urllib.request.urlopen(URL, timeout=20) as answer:
            return json.load(answer)
    except Exception as error:  # noqa: BLE001 — any failure to fetch is a skip, said loudly
        print(f"::warning::Could not fetch {URL} ({error}); request check skipped.")
        sys.exit(0)


def operation(spec, method, path):
    """The public operation whose path template matches: literal segments equal, {param} or $VAR any segment."""
    path = path.split("?", 1)[0]
    segments = [s for s in path.strip("/").split("/") if s]
    for template, operations in spec.get("paths", {}).items():
        parts = [p for p in template.strip("/").split("/") if p][1:]  # drop the leading "api"
        if len(parts) != len(segments) or method.lower() not in operations:
            continue
        if all(p.startswith("{") or s.startswith("$") or p == s for p, s in zip(parts, segments)):
            return operations[method.lower()]
    return None


def main():
    spec = load_spec()
    problems, checked = [], 0
    for script in sorted(pathlib.Path("examples").rglob("*.sh")):
        text = script.read_text()
        assignments = dict(ASSIGN.findall(text))
        bodies = {}
        for match in JQ_BODY.finditer(text):
            bodies.setdefault(match.group(1), []).append((match.start(), set(KEY.findall(match.group(2)))))
        for call in CALL.finditer(text):
            checked += 1
            method, path, body_var = call.groups()
            path = expand(path, assignments)
            where = f"{script}: {method} {path}"
            op = operation(spec, method, path)
            if op is None:
                problems.append(f"{where} — not a public operation in the API description")
                continue
            if body_var:
                # The nearest `body=$(jq … '{…}')` above this call.
                fields = next((keys for pos, keys in reversed(bodies.get(body_var, [])) if pos < call.start()), set())
                documented = (op.get("requestBody") or {}).get("content", {}).get("application/json", {}).get("schema", {}).get("properties", {})
                problems += [f"{where} — sends \"{f}\", which the operation does not document" for f in sorted(fields) if f not in documented]
    if checked < 10:
        problems.append(f"Read only {checked} calls — is the parser still matching the scripts?")
    for problem in problems:
        print(f"::error::{problem}")
    print(f"Checked {checked} API calls in examples/: {'all match' if not problems else f'{len(problems)} problem(s)'}.")
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
