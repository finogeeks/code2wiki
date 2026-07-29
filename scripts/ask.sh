#!/usr/bin/env bash
# REST ask against the local facade (first-success path — no FinClaw caller).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
PORT="${CODE2WIKI_PORT:-8080}"
Q="${*:-What can you answer about the registered sources?}"
curl -fsS "http://127.0.0.1:${PORT}/v1/ask" \
  -H 'content-type: application/json' \
  -d "$(python3 -c 'import json,sys; print(json.dumps({"question": sys.argv[1]}))' "$Q")"
echo
