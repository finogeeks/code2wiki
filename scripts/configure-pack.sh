#!/usr/bin/env bash
# Configure a pack: write sources.yaml + retrieval-eval.yaml (+ optional secrets).
#
# Non-interactive:
#   ./scripts/configure-pack.sh --pack acme \
#     --repo my-app=https://github.com/org/app.git \
#     --repo docs=https://github.com/org/docs.git --branch main \
#     --llm-key-file /path/to/key   # or LLM_API_KEY env
#
# Interactive (TTY): prompts for pack repos and secrets when flags omitted.
#
# Env:
#   CODE2WIKI_PROFILE / --pack
#   LLM_API_KEY, GH_TOKEN (optional writes into secrets/)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/prompt.sh"

PACK="${CODE2WIKI_PROFILE:-}"
BRANCH="main"
VISIBILITY="private"
DECLARED_REPOS=()
LLM_KEY_FILE=""
GH_TOKEN_FILE=""
NONINTERACTIVE=0
SKIP_SECRETS=0

usage() {
  sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'
}

slug_from_url() {
  local url="$1" base
  base="${url%/}"
  base="${base%.git}"
  base="${base##*/}"
  base="$(printf '%s' "$base" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^-+//; s/-+$//')"
  [[ -n "$base" ]] || base="source"
  printf '%s' "$base"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --pack) PACK="${2:-}"; shift 2 ;;
    --branch) BRANCH="${2:-main}"; shift 2 ;;
    --visibility) VISIBILITY="${2:-private}"; shift 2 ;;
    --repo)
      [[ -n "${2:-}" ]] || { echo "error: --repo needs id=url or url" >&2; exit 2; }
      DECLARED_REPOS+=("$2")
      shift 2
      ;;
    --llm-key-file) LLM_KEY_FILE="${2:-}"; shift 2 ;;
    --gh-token-file) GH_TOKEN_FILE="${2:-}"; shift 2 ;;
    --non-interactive) NONINTERACTIVE=1; shift ;;
    --skip-secrets) SKIP_SECRETS=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$PACK" ]]; then
  if [[ -f config/active-profile ]]; then
    PACK="$(tr -d '[:space:]' < config/active-profile)"
  else
    PACK="acme"
  fi
fi

if [[ ! "$PACK" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]]; then
  echo "error: invalid pack id: $PACK" >&2
  exit 2
fi

# Interactive repo collection when none provided.
if [[ ${#DECLARED_REPOS[@]} -eq 0 ]]; then
  if [[ "$NONINTERACTIVE" == 1 ]] || ! code2wiki_can_prompt; then
    echo "error: no --repo provided (required in non-interactive mode)" >&2
    echo "hint: --repo my-app=https://github.com/org/app.git" >&2
    exit 2
  fi
  echo "configure-pack: interactive — add one or more Git remotes (empty URL to finish)"
  while true; do
    url="$(code2wiki_prompt "Git remote URL (empty to finish)")"
    [[ -n "$url" ]] || break
    def_id="$(slug_from_url "$url")"
    sid="$(code2wiki_prompt "Source id" "$def_id")"
    DECLARED_REPOS+=("${sid}=${url}")
  done
  if [[ ${#DECLARED_REPOS[@]} -eq 0 ]]; then
    echo "error: at least one repo required" >&2
    exit 2
  fi
  BRANCH="$(code2wiki_prompt "Default branch" "$BRANCH")"
  VISIBILITY="$(code2wiki_prompt "visibility (private|public)" "$VISIBILITY")"
fi

SOURCES_JSON='[]'
for spec in "${DECLARED_REPOS[@]}"; do
  sid="" url=""
  if [[ "$spec" == *=* ]]; then
    sid="${spec%%=*}"
    url="${spec#*=}"
  else
    url="$spec"
    sid="$(slug_from_url "$url")"
  fi
  SOURCES_JSON="$(python3 -c '
import json,sys
arr=json.loads(sys.argv[1])
arr.append({
  "id": sys.argv[2],
  "remote_url": sys.argv[3],
  "default_branch": sys.argv[4],
  "visibility": sys.argv[5],
  "description": f"Primary corpus for {sys.argv[2]}.",
  "tags": [sys.argv[2]],
})
print(json.dumps(arr))
' "$SOURCES_JSON" "$sid" "$url" "$BRANCH" "$VISIBILITY")"
done

OUT="profiles/$PACK"
mkdir -p "$OUT"
PAYLOAD="$(python3 -c 'import json,sys; print(json.dumps({"pack":sys.argv[1],"sources":json.loads(sys.argv[2])}))' "$PACK" "$SOURCES_JSON")"
printf '%s' "$PAYLOAD" | python3 "$ROOT/scripts/lib/pack_yaml.py" --out-dir "$OUT"

# Refresh activated sources pointer for scrubber/ask before activate.
mkdir -p config
printf '%s\n' "$PACK" > config/active-profile
{
  echo "# ACTIVE SOURCES — from configure-pack (${PACK})"
  cat "$OUT/sources.yaml"
} > config/sources.yaml
if grep -q '^CODE2WIKI_PROFILE=' .env 2>/dev/null; then
  sed -i.bak "s/^CODE2WIKI_PROFILE=.*/CODE2WIKI_PROFILE=${PACK}/" .env && rm -f .env.bak
else
  echo "CODE2WIKI_PROFILE=${PACK}" >>.env
fi

write_secret() {
  local dest="$1" value="$2"
  [[ -n "$value" ]] || return 0
  umask 077
  printf '%s' "$value" >"$dest"
  chmod 600 "$dest"
  echo "configure-pack: wrote $dest"
}

if [[ "$SKIP_SECRETS" != 1 ]]; then
  if [[ -n "${LLM_API_KEY:-}" ]]; then
    write_secret secrets/llm_api_key "$LLM_API_KEY"
  elif [[ -n "$LLM_KEY_FILE" && -r "$LLM_KEY_FILE" ]]; then
    write_secret secrets/llm_api_key "$(tr -d '\r\n' <"$LLM_KEY_FILE")"
  elif code2wiki_can_prompt && [[ "$NONINTERACTIVE" != 1 ]]; then
    if [[ ! -s secrets/llm_api_key ]]; then
      key="$(code2wiki_prompt "LLM API key (empty to skip; needed for real answers)")"
      write_secret secrets/llm_api_key "$key"
    fi
  fi

  if [[ -n "${GH_TOKEN:-}" ]]; then
    write_secret secrets/gh_token "$GH_TOKEN"
  elif [[ -n "$GH_TOKEN_FILE" && -r "$GH_TOKEN_FILE" ]]; then
    write_secret secrets/gh_token "$(tr -d '\r\n' <"$GH_TOKEN_FILE")"
  elif code2wiki_can_prompt && [[ "$NONINTERACTIVE" != 1 ]]; then
    if [[ ! -s secrets/gh_token ]]; then
      tok="$(code2wiki_prompt "GitHub PAT for private remotes (empty if public HTTPS works)")"
      write_secret secrets/gh_token "$tok"
    fi
  fi

  # Ensure A2A peer token exists (facade may also mint; empty file is ok for init).
  if [[ ! -s secrets/a2a_peer_token ]]; then
    if command -v openssl >/dev/null 2>&1; then
      write_secret secrets/a2a_peer_token "$(openssl rand -hex 24)"
    else
      write_secret secrets/a2a_peer_token "$(python3 -c 'import secrets; print(secrets.token_hex(24))')"
    fi
  fi
fi

echo "configure-pack: pack=$PACK sources=${#DECLARED_REPOS[@]} → $OUT"
echo "next: ./scripts/pull-image.sh && ./scripts/up.sh && ./scripts/activate.sh $PACK && ./scripts/ingest.sh"
