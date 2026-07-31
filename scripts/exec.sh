#!/usr/bin/env bash
# Run a command inside the appliance container (cwd = image workspace).
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
if [[ $# -eq 0 ]]; then
  echo "usage: ./scripts/exec.sh <command> [args…]" >&2
  exit 2
fi
code2wiki_appliance_exec "$@"
