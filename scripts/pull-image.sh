#!/usr/bin/env bash
# Pull (or skip) the casst appliance image for this site.
#
# Registry images (name contains '/'): always docker pull by default so a
# republished mutable tag (e.g. :latest) refreshes when the remote digest
# changed. Up-to-date pulls are cheap ("Image is up to date").
#
#   CODE2WIKI_PULL=0  — airgap/offline: use local copy only (error if missing)
# Local images (e.g. code2wiki:dev): never pull unless CODE2WIKI_PULL=1.
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

# Registry refs look like host/path:tag (contain '/'). Bare tags are local builds.
is_registry=0
[[ "$IMAGE" == */* ]] && is_registry=1

want_pull=0
if [[ "$is_registry" == 1 ]]; then
  # Default on for registry; opt out with CODE2WIKI_PULL=0.
  [[ "${CODE2WIKI_PULL:-1}" != "0" ]] && want_pull=1
else
  # Local image: opt in with CODE2WIKI_PULL=1.
  [[ "${CODE2WIKI_PULL:-0}" == "1" ]] && want_pull=1
fi

present=0
docker image inspect "$IMAGE" >/dev/null 2>&1 && present=1

if [[ "$want_pull" == 1 ]]; then
  if [[ "$present" == 1 ]]; then
    echo "checking registry for updates: $IMAGE"
  else
    echo "pulling $IMAGE …"
  fi
  if ! docker pull "$IMAGE"; then
    if [[ "$present" == 1 ]]; then
      echo "warning: docker pull failed; continuing with local image $IMAGE" >&2
    else
      echo "error: cannot pull $IMAGE" >&2
      echo "hint: build privately (code2wiki:dev), set CODE2WIKI_IMAGE, or load an archive" >&2
      exit 1
    fi
  fi
elif [[ "$present" == 1 ]]; then
  echo "image present (skip pull): $IMAGE"
  if [[ "$is_registry" == 1 ]]; then
    echo "hint: omit CODE2WIKI_PULL=0 (or set =1) to refresh from the registry"
  fi
else
  echo "error: image not found locally: $IMAGE" >&2
  if [[ "$is_registry" == 1 ]]; then
    echo "hint: unset CODE2WIKI_PULL=0 and re-run, or docker pull $IMAGE" >&2
  else
    echo "hint: build the local image, or set CODE2WIKI_IMAGE to a registry tag" >&2
  fi
  exit 1
fi

echo "CODE2WIKI_IMAGE=$IMAGE"
