# shellcheck shell=bash
# Source from site scripts after loading .env.
# Prevents a parent-shell COMPOSE_PROJECT_NAME from steering another site's stack.
code2wiki_compose_env() {
  local root="${1:-.}"
  local envf="${root}/.env"
  local pinned=""
  if [[ -f "$envf" ]]; then
    pinned="$(grep -E '^COMPOSE_PROJECT_NAME=' "$envf" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
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
