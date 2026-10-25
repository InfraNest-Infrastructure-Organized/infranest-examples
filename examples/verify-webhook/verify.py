"""Verify that a webhook delivery came from InfraNest. https://developers.infranest.io/webhooks#verify-the-signature

  python3 verify.py BODY_FILE TIMESTAMP SIGNATURE     (TIMESTAMP '' when the header was absent)
  INFRANEST_WEBHOOK_SECRET   the endpoint's signing secret (whsec_...)
Exits 0 for a genuine delivery, 1 otherwise. Use verify_infranest() in your own receiver.
"""
import hashlib
import hmac
import os
import sys
import time


def verify_infranest(raw_body: bytes, headers, secret: str, tolerance: int = 300) -> bool:
    """raw_body: the request body as bytes, before json.loads."""
    signature = headers.get("X-InfraNest-Signature", "")
    timestamp = headers.get("X-InfraNest-Timestamp")
    signed = raw_body
    if timestamp is not None:
        if not timestamp.isdigit() or abs(time.time() - int(timestamp)) > tolerance:
            return False
        signed = timestamp.encode() + b"." + raw_body
    expected = "sha256=" + hmac.new(secret.encode(), signed, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


if __name__ == "__main__":
    body_file, timestamp, signature = sys.argv[1:4]
    headers = {"X-InfraNest-Signature": signature}
    if timestamp:
        headers["X-InfraNest-Timestamp"] = timestamp
    with open(body_file, "rb") as f:
        sys.exit(0 if verify_infranest(f.read(), headers, os.environ.get("INFRANEST_WEBHOOK_SECRET", "")) else 1)
