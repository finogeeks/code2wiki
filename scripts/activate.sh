#!/usr/bin/env bash
# Activate a pack inside the running appliance (writes config/ + .env profile).
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

PACK="${1:-}"
[[ -n "$PACK" ]] || { echo "usage: ./scripts/activate.sh <pack-id>" >&2; exit 2; }
[[ -d "profiles/$PACK" ]] || { echo "error: missing profiles/$PACK" >&2; exit 1; }

# Prefer in-container activate script from the image.
set +e
code2wiki_appliance_exec ./scripts/activate-profile.sh "$PACK"
rc=$?
set -e
if [[ "$rc" -ne 0 ]]; then
  # Docker Desktop often rejects `mv` onto a bind-mounted `.env` even after the
  # pack config was written. Accept success when config/ matches the pack.
  if [[ -f config/active-profile ]] && [[ "$(tr -d '[:space:]' <config/active-profile)" == "$PACK" ]] \
    && [[ -f config/sources.yaml ]]; then
    echo "warn: in-container activate exited ${rc}; continuing (config/${PACK} looks active)" >&2
  else
    echo "error: appliance activate-profile.sh failed (exit ${rc})" >&2
    exit "$rc"
  fi
fi

# Mirror CODE2WIKI_PROFILE into host .env for compose restarts
if grep -q '^CODE2WIKI_PROFILE=' .env 2>/dev/null; then
  sed -i.bak "s/^CODE2WIKI_PROFILE=.*/CODE2WIKI_PROFILE=${PACK}/" .env && rm -f .env.bak
else
  echo "CODE2WIKI_PROFILE=${PACK}" >>.env
fi
echo "activated pack: $PACK"
