#!/usr/bin/env bash
# Launch the FinClaw setup-guide profile against this site.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
if [[ -f runtime/.finclaw-env ]]; then
  # shellcheck disable=SC1091
  source runtime/.finclaw-env
fi

# shellcheck disable=SC1091
source "$ROOT/scripts/lib/site-base-url.sh"
export CASST_BASE_URL="$(code2wiki_site_base_url "$ROOT")"
CLIENT_HOME="${ROOT}/runtime/examples/finclaw-setup"
PROFILE="casst-caller"

command -v finclaw >/dev/null || ./scripts/ensure-finclaw.sh
if [[ -z "${CASST_A2A_PEER_TOKEN:-}" && -r secrets/a2a_peer_token ]]; then
  export CASST_A2A_PEER_TOKEN="$(tr -d '\r\n' < secrets/a2a_peer_token)"
fi
if [[ -z "${LLM_API_KEY:-}" && -s secrets/llm_api_key ]]; then
  export LLM_API_KEY="$(tr -d '\r\n' < secrets/llm_api_key)"
fi

./scripts/materialize-caller.sh finclaw-setup

MSG="${*:-Help me verify this casst site is SETUP_COMPLETE. Run ./scripts/setup-complete.sh if needed, then confirm A2A/MCP callers work. Keep steps short.}"

echo "run-setup-agent: FINCLAW_HOME=${CLIENT_HOME}"
FINCLAW_HOME="${CLIENT_HOME}" finclaw chat --profile "${PROFILE}" -m "${MSG}"
