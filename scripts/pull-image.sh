#!/usr/bin/env bash
# Pull (or skip) the casst appliance image for this site.
#
# Registry images: refresh by default (docker pull / container image pull).
#   CODE2WIKI_PULL=0  — airgap/offline
# Local images (e.g. code2wiki:dev): never pull unless CODE2WIKI_PULL=1.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
[[ -f .env ]] && set -a && source .env && set +a
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/compose-env.sh"
code2wiki_compose_env "$ROOT"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/docker-runtime.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/appliance-runtime.sh"

code2wiki_appliance_pull
