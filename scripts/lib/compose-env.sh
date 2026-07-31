# shellcheck shell=bash
# Source from site scripts after loading .env.
# Prevents a parent-shell COMPOSE_PROJECT_NAME from steering another site's stack.
# Restores CODE2WIKI_RUNTIME + DOCKER_CONTEXT pinned by get-started.
code2wiki_compose_env() {
  local root="${1:-.}"
  local envf="${root}/.env"
  local pinned=""
  local dctx=""
  local rt=""
  if [[ -f "$envf" ]]; then
    pinned="$(grep -E '^COMPOSE_PROJECT_NAME=' "$envf" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
    dctx="$(grep -E '^DOCKER_CONTEXT=' "$envf" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
    rt="$(grep -E '^CODE2WIKI_RUNTIME=' "$envf" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
  fi
  if [[ -n "$rt" ]]; then
    export CODE2WIKI_RUNTIME="$rt"
  else
    export CODE2WIKI_RUNTIME="${CODE2WIKI_RUNTIME:-compose}"
  fi
  if [[ "${CODE2WIKI_RUNTIME}" == "compose" && -n "$dctx" ]]; then
    export DOCKER_CONTEXT="$dctx"
    unset DOCKER_HOST || true
  fi
  if [[ -n "$pinned" ]]; then
    export COMPOSE_PROJECT_NAME="$pinned"
  else
    unset COMPOSE_PROJECT_NAME || true
    local base pack
    base="$(basename "$(cd "$root" && pwd)")"
    pack=""
    if [[ -f "${root}/config/active-profile" ]]; then
      pack="$(tr -d '[:space:]' <"${root}/config/active-profile")"
    fi
    pack="${pack:-${CODE2WIKI_PROFILE:-$base}}"
    pack="$(printf '%s' "$pack" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_-]+/-/g')"
    export COMPOSE_PROJECT_NAME="casst-${pack}"
  fi
}
