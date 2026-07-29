#!/usr/bin/env bash
# REST ask against the local facade (first-success path — no FinClaw caller).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
PORT="${CODE2WIKI_PORT:-8080}"
Q="${*:-What can you answer about the registered sources?}"
BODY="$(python3 -c 'import json,sys; print(json.dumps({"question": sys.argv[1]}))' "$Q")"
RESP="$(curl -fsS "http://127.0.0.1:${PORT}/v1/ask" \
  -H 'content-type: application/json' \
  -d "$BODY")"
if command -v python3 >/dev/null 2>&1; then
  printf '%s\n' "$RESP" | python3 -m json.tool 2>/dev/null || printf '%s\n' "$RESP"
else
  printf '%s\n' "$RESP"
fi
