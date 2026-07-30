#!/usr/bin/env bash
# Host FinClaw → casst over A2A (one-shot chat).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
if [[ -f runtime/.finclaw-env ]]; then
  # shellcheck disable=SC1091
  source runtime/.finclaw-env
fi

CLIENT_HOME="${FINCLAW_A2A_CLIENT_HOME:-${ROOT}/runtime/examples/finclaw-a2a}"
PROFILE="${FINCLAW_A2A_CLIENT_PROFILE:-casst-caller}"
TOKEN_FILE="${CASST_A2A_PEER_TOKEN_FILE:-${ROOT}/secrets/a2a_peer_token}"
KEY_FILE="${LLM_API_KEY_FILE:-${ROOT}/secrets/llm_api_key}"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/site-base-url.sh"
export CASST_BASE_URL="$(code2wiki_site_base_url "$ROOT")"

QUESTION="${*:-}"
if [[ -z "$QUESTION" ]]; then
  echo "usage: ./scripts/ask-casst-a2a.sh <question>" >&2
  exit 2
fi

command -v finclaw >/dev/null || {
  echo "error: finclaw not on PATH (./scripts/ensure-finclaw.sh)" >&2
  exit 1
}

if [[ -z "${CASST_A2A_PEER_TOKEN:-}" && -r "$TOKEN_FILE" ]]; then
  export CASST_A2A_PEER_TOKEN="$(tr -d '\r\n' <"$TOKEN_FILE")"
fi
[[ -n "${CASST_A2A_PEER_TOKEN:-}" ]] || {
  echo "error: set CASST_A2A_PEER_TOKEN or secrets/a2a_peer_token" >&2
  exit 1
}

if [[ -z "${LLM_API_KEY:-}" && -r "$KEY_FILE" && -s "$KEY_FILE" ]]; then
  export LLM_API_KEY="$(tr -d '\r\n' <"$KEY_FILE")"
fi
[[ -n "${LLM_API_KEY:-}" || "${CASST_MOCK:-0}" == "1" ]] || {
  echo "error: LLM_API_KEY required for host FinClaw chat (or CASST_MOCK=1 for facade-only smokes)" >&2
  exit 1
}

./scripts/materialize-caller.sh finclaw-a2a >/dev/null
FINCLAW_HOME="${CLIENT_HOME}" finclaw chat --profile "${PROFILE}" -m "${QUESTION}"
