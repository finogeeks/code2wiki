#!/usr/bin/env bash
# End-to-end completion gate for a casst site.
#
# Assumes: pack configured, secrets present, compose up, activated, ingested.
#
# Steps:
#   1) doctor / healthz
#   2) smoke-facade (REST + A2A)
#   3) materialize FinClaw callers + A2A probe + MCP outbound-test
#   4) optional host FinClaw chat asks (skipped if no LLM_API_KEY / --no-chat)
#   5) print SETUP_COMPLETE badge
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
if [[ -f runtime/.finclaw-env ]]; then
  # shellcheck disable=SC1091
  source runtime/.finclaw-env
fi

NO_CHAT=0
SKIP_FINCLAW_CALLER=0
PRODUCT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-chat) NO_CHAT=1; shift ;;
    --skip-finclaw-caller) SKIP_FINCLAW_CALLER=1; shift ;;
    --product) PRODUCT="${2:-}"; shift 2 ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Prefer this site's .env over a parent-shell CASST_BASE_URL.
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/site-base-url.sh"
PORT="$(grep -E '^CODE2WIKI_PORT=' .env 2>/dev/null | cut -d= -f2- || true)"
PORT="${PORT:-${CODE2WIKI_PORT:-8080}}"
BASE="$(code2wiki_site_base_url "$ROOT")"
export BASE CASST_BASE_URL="$BASE"
PACK="$(tr -d '[:space:]' < config/active-profile 2>/dev/null || true)"
PACK="${PACK:-${CODE2WIKI_PROFILE:-acme}}"

if [[ -z "$PRODUCT" ]]; then
  PRODUCT="$(python3 - <<'PY' || true
import re
from pathlib import Path
text = Path("config/sources.yaml").read_text(encoding="utf-8") if Path("config/sources.yaml").exists() else ""
ids = re.findall(r"^\s*-\s*id:\s*([A-Za-z0-9._-]+)\s*$", text, flags=re.M)
print(ids[0] if ids else "")
PY
)"
fi

echo "== setup-complete: base=${BASE} pack=${PACK} product=${PRODUCT:-'(none)'} =="

./scripts/doctor.sh

ARGS=()
[[ -n "$PRODUCT" ]] && ARGS+=("$PRODUCT")
./scripts/smoke-facade.sh "${ARGS[@]+"${ARGS[@]}"}"

if [[ "$SKIP_FINCLAW_CALLER" == 1 ]]; then
  echo "setup-complete: skipping FinClaw caller materialize (--skip-finclaw-caller)"
else
  command -v finclaw >/dev/null || ./scripts/ensure-finclaw.sh
  export CASST_BASE_URL="$BASE"
  ./scripts/materialize-caller.sh finclaw-a2a
  ./scripts/materialize-caller.sh finclaw-mcp

  if [[ -z "${CASST_A2A_PEER_TOKEN:-}" && -r secrets/a2a_peer_token ]]; then
    export CASST_A2A_PEER_TOKEN="$(tr -d '\r\n' < secrets/a2a_peer_token)"
  fi

  echo "==> finclaw a2a probe casst"
  FINCLAW_HOME="${ROOT}/runtime/examples/finclaw-a2a" \
    finclaw a2a probe --profile casst-caller casst

  echo "==> finclaw mcp outbound-test"
  FINCLAW_HOME="${ROOT}/runtime/examples/finclaw-mcp" \
    AI_INFRA_RS_HOME="${ROOT}/runtime/examples/finclaw-mcp/profiles/casst-caller/runtime_home" \
    finclaw mcp outbound-test casst-mcp --timeout 30

  if [[ "$NO_CHAT" != 1 ]]; then
    if [[ -z "${LLM_API_KEY:-}" && -s secrets/llm_api_key ]]; then
      export LLM_API_KEY="$(tr -d '\r\n' < secrets/llm_api_key)"
    fi
    if [[ -n "${LLM_API_KEY:-}" && "${CASST_MOCK:-0}" != "1" ]]; then
      Q="In one short sentence: confirm you reached casst and list the product id ${PRODUCT:-unknown}."
      echo "==> FinClaw A2A chat smoke"
      ./scripts/ask-casst-a2a.sh "$Q" || {
        echo "warn: A2A chat smoke failed (facade smokes already passed)" >&2
      }
      echo "==> FinClaw MCP chat smoke"
      ./scripts/ask-casst-mcp.sh "$Q" || {
        echo "warn: MCP chat smoke failed (outbound-test already passed)" >&2
      }
    else
      echo "setup-complete: skipping host chat (no LLM_API_KEY or CASST_MOCK=1); facade+probe OK"
    fi
  fi
fi

BADGE_PATH="runtime/eval/SETUP_COMPLETE.json"
mkdir -p runtime/eval
if [[ "$SKIP_FINCLAW_CALLER" == 1 ]]; then
  FINCLAW_CALLER_PY=False
else
  FINCLAW_CALLER_PY=True
fi
python3 - <<PY
import json, os
from datetime import datetime, timezone
from pathlib import Path
payload = {
  "ok": True,
  "badge": "SETUP_COMPLETE",
  "ts": datetime.now(timezone.utc).isoformat(),
  "base_url": os.environ.get("BASE", ""),
  "pack": "${PACK}",
  "product": "${PRODUCT}",
  "checks": {
    "doctor": True,
    "rest_ask": True,
    "a2a_send": True,
    "finclaw_caller": ${FINCLAW_CALLER_PY},
  },
}
Path("${BADGE_PATH}").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
print(json.dumps(payload, indent=2))
PY

cat <<EOF

========================================
  SETUP_COMPLETE
  facade:  ${BASE}
  pack:    ${PACK}
  console: ${BASE}/operator
  badge:   ${BADGE_PATH}
========================================

EOF
