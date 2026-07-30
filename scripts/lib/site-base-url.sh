# shellcheck shell=bash
# Resolve this site's facade base URL (ignore a parent-shell CASST_BASE_URL that
# points at another appliance).
code2wiki_site_base_url() {
  local root="${1:-.}"
  local port public
  port="${CODE2WIKI_PORT:-8080}"
  if [[ -f "${root}/.env" ]]; then
    local from_env
    from_env="$(grep -E '^CODE2WIKI_PORT=' "${root}/.env" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
    [[ -n "$from_env" ]] && port="$from_env"
  fi
  public=""
  if [[ -f "${root}/.env" ]]; then
    public="$(grep -E '^CASST_PUBLIC_BASE_URL=' "${root}/.env" 2>/dev/null | tail -1 | cut -d= -f2- || true)"
  fi
  if [[ -n "$public" ]]; then
    printf '%s' "${public%/}"
    return 0
  fi
  printf 'http://127.0.0.1:%s' "$port"
}
