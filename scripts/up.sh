#!/usr/bin/env bash
# Start the casst facade for this site (docker compose).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

[[ -f .env ]] && set -a && source .env && set +a
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/compose-env.sh"
code2wiki_compose_env "$ROOT"

VER="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo latest)"
if [[ -z "${CODE2WIKI_IMAGE:-}" ]]; then
  if [[ "$VER" == "0.0.0-dev" ]]; then
    export CODE2WIKI_IMAGE=code2wiki:dev
  else
    export CODE2WIKI_IMAGE="ghcr.io/finogeeks/code2wiki:${VER}"
  fi
fi

for f in secrets/llm_api_key secrets/gh_token secrets/a2a_peer_token; do
  if [[ ! -f "$f" ]]; then
    echo "error: missing $f — run init-site / ensure-secrets" >&2
    exit 1
  fi
done

# Compose requires secret files to exist; empty is ok for mock smoke.
mkdir -p runtime/{finclaw,hermes,answer-cache,data,bundles,logs,eval,examples} config

echo "using image: $CODE2WIKI_IMAGE (compose project: ${COMPOSE_PROJECT_NAME})"
docker compose up -d
echo "facade: http://127.0.0.1:${CODE2WIKI_PORT:-8080}/healthz"
