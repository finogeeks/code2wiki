#!/usr/bin/env bash
# Start the casst facade for this site (Compose or Apple Container).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

[[ -f .env ]] && set -a && source .env && set +a
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/compose-env.sh"
code2wiki_compose_env "$ROOT"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/docker-runtime.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/appliance-runtime.sh"

for f in secrets/llm_api_key secrets/gh_token secrets/a2a_peer_token; do
  if [[ ! -f "$f" ]]; then
    echo "error: missing $f — run init-site / ensure-secrets" >&2
    exit 1
  fi
done

code2wiki_appliance_up
