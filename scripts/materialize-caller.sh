#!/usr/bin/env bash
# Materialize a FinClaw caller home from templates/callers/<id>.
#
# Usage:
#   ./scripts/materialize-caller.sh finclaw-a2a
#   ./scripts/materialize-caller.sh finclaw-mcp
#   CASST_BASE_URL=http://127.0.0.1:18080 ./scripts/materialize-caller.sh finclaw-a2a
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
if [[ -f runtime/.finclaw-env ]]; then
  # shellcheck disable=SC1091
  source runtime/.finclaw-env
fi

PROFILE="casst-caller"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/site-base-url.sh"
PORT="$(grep -E '^CODE2WIKI_PORT=' .env 2>/dev/null | cut -d= -f2- || true)"
PORT="${PORT:-${CODE2WIKI_PORT:-8080}}"
CASST_BASE_URL="$(code2wiki_site_base_url "$ROOT")"
export CASST_BASE_URL
# Always derive peer URLs from this site's base (ignore parent-shell CASST_*_URL).
CASST_A2A_URL="${CASST_BASE_URL}/a2a/v1"
CASST_MCP_URL="${CASST_BASE_URL}/mcp"
TOKEN_FILE="${CASST_A2A_PEER_TOKEN_FILE:-${ROOT}/secrets/a2a_peer_token}"

log() { printf '[materialize-caller] %s\n' "$*"; }
die() { printf '[materialize-caller] ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/materialize-caller.sh <finclaw-a2a|finclaw-mcp|finclaw-setup>
EOF
  exit 2
}

[[ $# -ge 1 ]] || usage
ID="$1"
case "$ID" in
  -h|--help) usage ;;
  finclaw-a2a|finclaw-mcp|finclaw-setup) ;;
  *) die "unsupported id: $ID" ;;
esac

# Prefer site-local templates; fall back to intake path if running from intake.
SRC=""
for candidate in \
  "${ROOT}/templates/callers/${ID}" \
  "${ROOT}/docs/public-code2wiki/templates/callers/${ID}"; do
  if [[ -d "$candidate" ]]; then SRC="$candidate"; break; fi
done
# When executed from an initialized site, templates live under templates/callers.
if [[ -z "$SRC" && -d "${ROOT}/templates/callers/${ID}" ]]; then
  SRC="${ROOT}/templates/callers/${ID}"
fi
[[ -d "$SRC" ]] || die "missing templates/callers/${ID} (re-run init-site from a current intake)"

DEST_HOME="${EXAMPLE_CALLER_HOME:-${ROOT}/runtime/examples/${ID}}"
case "$(cd "$(dirname "$DEST_HOME")" 2>/dev/null && pwd -P)/$(basename "$DEST_HOME")" in
  */runtime/finclaw|*/runtime/finclaw/*|*/runtime/hermes|*/runtime/hermes/*)
    die "refusing to materialize into appliance runtime/finclaw or runtime/hermes"
    ;;
esac

render_template() {
  local src="$1" dest="$2" placeholder="$3" value="$4" content
  [[ -f "$src" ]] || die "missing template: $src"
  mkdir -p "$(dirname "$dest")"
  content="$(cat "$src"; printf x)"
  content="${content%x}"
  content="${content//"${placeholder}"/"${value}"}"
  printf '%s' "$content" >"$dest"
}

maybe_load_a2a_token() {
  if [[ -z "${CASST_A2A_PEER_TOKEN:-}" && -r "$TOKEN_FILE" ]]; then
    CASST_A2A_PEER_TOKEN="$(tr -d '\r\n' <"$TOKEN_FILE")"
    export CASST_A2A_PEER_TOKEN
  fi
}

maybe_apply_llm_config() {
  local dest_home="$1"
  [[ "${CASST_MOCK:-0}" != "1" ]] || return 0
  [[ -n "${LLM_PROVIDER:-}" && "${LLM_PROVIDER}" != "mock" ]] || return 0
  command -v finclaw >/dev/null || die "finclaw not on PATH"
  # Skip when no key is available — init already left a stub config.
  if [[ -z "${LLM_API_KEY:-}" ]]; then
    if [[ -s "${ROOT}/secrets/llm_api_key" ]]; then
      LLM_API_KEY="$(tr -d '\r\n' <"${ROOT}/secrets/llm_api_key")"
      export LLM_API_KEY
    else
      log "skip llm config set (no LLM_API_KEY)"
      return 0
    fi
  fi
  [[ -n "${LLM_API_KEY:-}" ]] || { log "skip llm config set (empty key)"; return 0; }
  FINCLAW_HOME="${dest_home}" finclaw config set --profile "${PROFILE}" \
    llm.provider "${LLM_PROVIDER}" >/dev/null || {
    log "warn: finclaw config set llm.provider failed (continuing)"
    return 0
  }
  [[ -n "${LLM_MODEL:-}" ]] && \
    FINCLAW_HOME="${dest_home}" finclaw config set --profile "${PROFILE}" \
      llm.model "${LLM_MODEL}" >/dev/null || true
  [[ -n "${LLM_BASE_URL:-}" ]] && \
    FINCLAW_HOME="${dest_home}" finclaw config set --profile "${PROFILE}" \
      llm.base_url "${LLM_BASE_URL}" >/dev/null || true
}

ensure_finclaw_profile() {
  local dest_home="$1"
  local profile_dir="${dest_home}/profiles/${PROFILE}"
  command -v finclaw >/dev/null || die "finclaw not on PATH (run ./scripts/ensure-finclaw.sh)"
  mkdir -p "${dest_home}"
  if [[ ! -f "${profile_dir}/profile.yaml" ]] \
    || ! grep -q 'schema_version' "${profile_dir}/profile.yaml" 2>/dev/null; then
    log "finclaw init --profile ${PROFILE}"
    if ! FINCLAW_HOME="${dest_home}" finclaw init --non-interactive --profile "${PROFILE}"; then
      [[ -f "${profile_dir}/profile.yaml" ]] \
        || die "finclaw init failed and profile.yaml missing"
      log "warn: finclaw init exited non-zero; profile.yaml present — continuing"
    fi
  fi
  mkdir -p \
    "${profile_dir}/runtime_home/config" \
    "${profile_dir}/config" \
    "${profile_dir}/workspace" \
    "${profile_dir}/agents/default/workspace" \
    "${profile_dir}/policies"
}

install_docs() {
  local src="$1" profile_dir="$2" f dest
  for f in IDENTITY.md AGENT.md TOOLS.md; do
    [[ -f "${src}/${f}" ]] || die "missing ${src}/${f}"
    cp "${src}/${f}" "${profile_dir}/${f}"
    for dest in "${profile_dir}/workspace" "${profile_dir}/agents/default/workspace"; do
      mkdir -p "${dest}"
      cp "${src}/${f}" "${dest}/${f}"
    done
  done
  if [[ -f "${src}/tool-invocation-policy.yaml" ]]; then
    cp "${src}/tool-invocation-policy.yaml" \
      "${profile_dir}/policies/tool-invocation-policy.yaml"
  fi
}

log "SRC=${SRC}"
log "DEST=${DEST_HOME}"
log "CASST_BASE_URL=${CASST_BASE_URL}"

profile_dir="${DEST_HOME}/profiles/${PROFILE}"
ensure_finclaw_profile "${DEST_HOME}"
install_docs "${SRC}" "${profile_dir}"

case "$ID" in
  finclaw-a2a)
    maybe_load_a2a_token
    render_template \
      "${SRC}/a2a-agents.yaml.template" \
      "${profile_dir}/runtime_home/config/a2a-agents.yaml" \
      '__CASST_A2A_URL__' "${CASST_A2A_URL}"
    cp "${profile_dir}/runtime_home/config/a2a-agents.yaml" \
      "${profile_dir}/config/a2a-agents.yaml"
    ;;
  finclaw-mcp)
    render_template \
      "${SRC}/mcp-servers.yaml.template" \
      "${profile_dir}/runtime_home/config/mcp-servers.yaml" \
      '__CASST_MCP_URL__' "${CASST_MCP_URL}"
    ;;
  finclaw-setup)
    # Setup agent: both A2A peer + shell access docs; optional MCP.
    if [[ -f "${SRC}/a2a-agents.yaml.template" ]]; then
      maybe_load_a2a_token
      render_template \
        "${SRC}/a2a-agents.yaml.template" \
        "${profile_dir}/runtime_home/config/a2a-agents.yaml" \
        '__CASST_A2A_URL__' "${CASST_A2A_URL}"
      cp "${profile_dir}/runtime_home/config/a2a-agents.yaml" \
        "${profile_dir}/config/a2a-agents.yaml"
    fi
    ;;
esac

maybe_apply_llm_config "${DEST_HOME}"
log "Done. FINCLAW_HOME=${DEST_HOME} profile=${PROFILE}"
