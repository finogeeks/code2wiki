#!/usr/bin/env bash
# Activate a pack inside the running appliance (writes config/ + .env profile).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
PACK="${1:-}"
[[ -n "$PACK" ]] || { echo "usage: ./scripts/activate.sh <pack-id>" >&2; exit 2; }
[[ -d "profiles/$PACK" ]] || { echo "error: missing profiles/$PACK" >&2; exit 1; }

# Prefer in-container activate script from the image.
if docker compose exec -T code2wiki test -x ./scripts/activate-profile.sh 2>/dev/null; then
  docker compose exec -T code2wiki ./scripts/activate-profile.sh "$PACK"
else
  echo "error: appliance image missing activate-profile.sh — is CODE2WIKI_IMAGE correct?" >&2
  exit 1
fi

# Mirror CODE2WIKI_PROFILE into host .env for compose restarts
if grep -q '^CODE2WIKI_PROFILE=' .env 2>/dev/null; then
  sed -i.bak "s/^CODE2WIKI_PROFILE=.*/CODE2WIKI_PROFILE=${PACK}/" .env && rm -f .env.bak
else
  echo "CODE2WIKI_PROFILE=${PACK}" >>.env
fi
echo "activated pack: $PACK"
