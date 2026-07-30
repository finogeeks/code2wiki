#!/usr/bin/env bash
# REST ask against the local facade (first-success path — no FinClaw caller).
#
# Usage:
#   ./scripts/ask.sh "How do I deploy?"
#   ./scripts/ask.sh "How do I deploy?" --product acme-docs
#   ./scripts/ask.sh --product acme-docs "settle failures?"
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
PORT="${CODE2WIKI_PORT:-8080}"
TIMEOUT="${CODE2WIKI_ASK_TIMEOUT:-180}"

PRODUCTS=()
Q_PARTS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --product|--products)
      [[ -n "${2:-}" ]] || { echo "error: $1 needs a value" >&2; exit 2; }
      _rest="$2"
      while [[ -n "$_rest" ]]; do
        _p="${_rest%%,*}"
        if [[ "$_rest" == "$_p" ]]; then
          _rest=""
        else
          _rest="${_rest#*,}"
        fi
        _p="${_p#"${_p%%[![:space:]]*}"}"
        _p="${_p%"${_p##*[![:space:]]}"}"
        [[ -n "$_p" ]] && PRODUCTS+=("$_p")
      done
      shift 2
      ;;
    -h|--help)
      sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      Q_PARTS+=("$1")
      shift
      ;;
  esac
done

if [[ ${#Q_PARTS[@]} -eq 0 ]]; then
  Q="What can you answer about the registered sources?"
else
  Q="${Q_PARTS[*]}"
fi

# Auto-scope when the active pack has exactly one source id (facade needs products[]).
# Prefer PyYAML when available; otherwise a light regex over `id:` lines.
if [[ ${#PRODUCTS[@]} -eq 0 && -n "${CODE2WIKI_PROFILE:-}" && -f "profiles/${CODE2WIKI_PROFILE}/sources.yaml" ]]; then
  _auto="$(
    python3 - "$CODE2WIKI_PROFILE" <<'PY'
import re, sys
from pathlib import Path
text = Path(f"profiles/{sys.argv[1]}/sources.yaml").read_text(encoding="utf-8")
try:
    import yaml
    doc = yaml.safe_load(text) or {}
    ids = [str(s.get("id") or "").strip() for s in (doc.get("sources") or []) if isinstance(s, dict)]
except Exception:
    ids = re.findall(r"(?m)^\s*-\s*id:\s*([A-Za-z0-9][A-Za-z0-9_-]*)\s*$", text)
    if not ids:
        ids = re.findall(r"(?m)^\s*id:\s*([A-Za-z0-9][A-Za-z0-9_-]*)\s*$", text)
ids = [i for i in ids if i]
if len(ids) == 1:
    print(ids[0])
PY
  )"
  if [[ -n "$_auto" ]]; then
    PRODUCTS+=("$_auto")
  fi
fi

BODY="$(
  export ASK_Q="$Q"
  if [[ ${#PRODUCTS[@]} -gt 0 ]]; then
    export ASK_PRODUCTS="$(printf '%s\n' "${PRODUCTS[@]}")"
  else
    export ASK_PRODUCTS=""
  fi
  python3 - <<'PY'
import json, os
q = os.environ["ASK_Q"]
products = [p for p in os.environ.get("ASK_PRODUCTS", "").splitlines() if p.strip()]
body = {"question": q}
if products:
    body["products"] = products
print(json.dumps(body, ensure_ascii=False))
PY
)"

echo "POST http://127.0.0.1:${PORT}/v1/ask  (timeout=${TIMEOUT}s)" >&2
if [[ ${#PRODUCTS[@]} -gt 0 ]]; then
  echo "products: ${PRODUCTS[*]}" >&2
fi

RESP="$(curl -fsS --max-time "$TIMEOUT" "http://127.0.0.1:${PORT}/v1/ask" \
  -H 'content-type: application/json' \
  -d "$BODY")"
if command -v python3 >/dev/null 2>&1; then
  printf '%s\n' "$RESP" | python3 -m json.tool 2>/dev/null || printf '%s\n' "$RESP"
else
  printf '%s\n' "$RESP"
fi
