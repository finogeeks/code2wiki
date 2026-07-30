#!/usr/bin/env bash
# Host FinClaw → casst over MCP (outbound-test + optional chat).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
if [[ -f runtime/.finclaw-env ]]; then
  # shellcheck disable=SC1091
  source runtime/.finclaw-env
fi

CLIENT_HOME="${FINCLAW_MCP_CLIENT_HOME:-${ROOT}/runtime/examples/finclaw-mcp}"
PROFILE="${FINCLAW_MCP_CLIENT_PROFILE:-casst-caller}"
KEY_FILE="${LLM_API_KEY_FILE:-${ROOT}/secrets/llm_api_key}"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/site-base-url.sh"
export CASST_BASE_URL="$(code2wiki_site_base_url "$ROOT")"
QUESTION="${*:-}"

command -v finclaw >/dev/null || {
  echo "error: finclaw not on PATH (./scripts/ensure-finclaw.sh)" >&2
  exit 1
}

if [[ -z "${LLM_API_KEY:-}" && -r "$KEY_FILE" && -s "$KEY_FILE" ]]; then
  export LLM_API_KEY="$(tr -d '\r\n' <"$KEY_FILE")"
fi

./scripts/materialize-caller.sh finclaw-mcp >/dev/null

PROFILE_DIR="${CLIENT_HOME}/profiles/${PROFILE}"
echo "==> finclaw mcp outbound-test casst-mcp"
FINCLAW_HOME="${CLIENT_HOME}" \
  AI_INFRA_RS_HOME="${PROFILE_DIR}/runtime_home" \
  finclaw mcp outbound-test casst-mcp --timeout 30

if [[ -n "$QUESTION" ]]; then
  [[ -n "${LLM_API_KEY:-}" ]] || {
    echo "error: LLM_API_KEY required for MCP chat ask" >&2
    exit 1
  }
  echo "==> finclaw chat (expect casst-mcp tools)"
  FINCLAW_HOME="${CLIENT_HOME}" finclaw chat --profile "${PROFILE}" -m "${QUESTION}"
fi
