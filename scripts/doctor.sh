#!/usr/bin/env bash
# Probe /healthz for this site.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
PORT="${CODE2WIKI_PORT:-8080}"
URL="http://127.0.0.1:${PORT}/healthz"
echo "GET $URL"
curl -fsS "$URL" | python3 -m json.tool 2>/dev/null || curl -fsS "$URL"
echo
