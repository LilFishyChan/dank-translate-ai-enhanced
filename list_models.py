#!/usr/bin/env python3
"""Fetch the /v1/models list from an OpenAI-compatible local server.

Reads DTAI_BASE_URL / DTAI_API_KEY from the environment on purpose: passing the
key as an argv would expose it in `ps`, and this helper never prints the key.

Prints JSON on stdout: {"models": [...]} or {"error": "..."}.
"""
import json
import os
import sys
import urllib.error
import urllib.request


def main() -> int:
    base = (os.environ.get("DTAI_BASE_URL") or "").strip().rstrip("/")
    key = (os.environ.get("DTAI_API_KEY") or "").strip()
    if not base:
        print(json.dumps({"error": "empty base url"}, ensure_ascii=False))
        return 1

    req = urllib.request.Request(base + "/models")
    req.add_header("Accept", "application/json")
    if key:
        req.add_header("Authorization", "Bearer " + key)

    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            payload = json.loads(resp.read().decode("utf-8", "ignore"))
    except urllib.error.HTTPError as exc:
        print(json.dumps({"error": "HTTP %s" % exc.code}, ensure_ascii=False))
        return 1
    except Exception as exc:  # noqa: BLE001 - report any transport failure verbatim
        print(json.dumps({"error": str(exc)}, ensure_ascii=False))
        return 1

    items = payload.get("data") if isinstance(payload, dict) else None
    models = []
    for item in items or []:
        mid = str((item or {}).get("id") or "").strip()
        if mid and mid not in models:
            models.append(mid)

    print(json.dumps({"models": models}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
