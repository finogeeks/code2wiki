#!/usr/bin/env bash
# Pull (or skip) the casst appliance image for this site.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# shellcheck disable=SC1091
[[ -f .env ]] && set -a && source .env && set +a

VER="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo latest)"
IMAGE="${CODE2WIKI_IMAGE:-ghcr.io/finogeeks/code2wiki:${VER}}"
if [[ "$VER" == "0.0.0-dev" && -z "${CODE2WIKI_IMAGE:-}" ]]; then
  IMAGE="${CODE2WIKI_IMAGE:-code2wiki:dev}"
  echo "VERSION is 0.0.0-dev — defaulting to local image: $IMAGE"
  echo "(set CODE2WIKI_IMAGE=ghcr.io/finogeeks/code2wiki:<ver> when published)"
fi

export CODE2WIKI_IMAGE="$IMAGE"
if docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "image present: $IMAGE"
  if [[ "${CODE2WIKI_PULL:-0}" == "1" ]]; then
    docker pull "$IMAGE"
  fi
else
  echo "pulling $IMAGE …"
  if ! docker pull "$IMAGE"; then
    echo "error: cannot pull $IMAGE" >&2
    echo "hint: build privately (code2wiki:dev) or set CODE2WIKI_IMAGE" >&2
    exit 1
  fi
fi
echo "CODE2WIKI_IMAGE=$IMAGE"
