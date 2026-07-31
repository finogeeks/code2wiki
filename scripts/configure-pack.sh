#!/usr/bin/env bash
# Configure a pack: write sources.yaml + retrieval-eval.yaml (+ optional secrets/LLM).
#
# Non-interactive:
#   ./scripts/configure-pack.sh --pack acme \
#     --repo my-app=https://github.com/org/app.git \
#     --llm-provider openai --llm-model gpt-4.1 \
#     --llm-base-url '' --llm-key-file /path/to/key
#
# Interactive (TTY): prompts for remotes, LLM provider/URL/model/key, and secrets.
#
# Env:
#   CODE2WIKI_PROFILE / --pack
#   LLM_PROVIDER, LLM_BASE_URL, LLM_MODEL, LLM_API_KEY, GH_TOKEN
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/prompt.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/i18n.sh"
code2wiki_i18n_init

PACK="${CODE2WIKI_PROFILE:-}"
BRANCH="main"
VISIBILITY="private"
DECLARED_REPOS=()
LLM_KEY_FILE=""
GH_TOKEN_FILE=""
LLM_PROVIDER_OPT="${LLM_PROVIDER:-}"
LLM_BASE_URL_OPT="${LLM_BASE_URL:-}"
LLM_MODEL_OPT="${LLM_MODEL:-}"
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

# Upsert KEY=VALUE in .env (create file if missing). Safe for URLs with /.
upsert_env() {
  local key="$1" value="$2"
  touch .env
  python3 -c '
import pathlib,sys
path=pathlib.Path(".env")
key,value=sys.argv[1],sys.argv[2].replace("\n","").replace("\r","")
lines=path.read_text(encoding="utf-8").splitlines() if path.stat().st_size else []
prefix=key+"="
out=[]; found=False
for line in lines:
    if line.startswith(prefix):
        out.append(prefix+value); found=True
    else:
        out.append(line)
if not found:
    out.append(prefix+value)
path.write_text("\n".join(out)+("\n" if out else ""), encoding="utf-8")
' "$key" "$value"
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
    --llm-provider) LLM_PROVIDER_OPT="${2:-}"; shift 2 ;;
    --llm-base-url) LLM_BASE_URL_OPT="${2:-}"; shift 2 ;;
    --llm-model) LLM_MODEL_OPT="${2:-}"; shift 2 ;;
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
    echo "$(code2wiki_t cfg_err_no_repo)" >&2
    echo "$(code2wiki_t cfg_hint_repo)" >&2
    exit 2
  fi
  echo "$(code2wiki_t cfg_interactive)"
  while true; do
    url="$(code2wiki_prompt "$(code2wiki_t cfg_git_url)")"
    [[ -n "$url" ]] || break
    def_id="$(slug_from_url "$url")"
    sid="$(code2wiki_prompt "$(code2wiki_t cfg_source_id)" "$def_id")"
    DECLARED_REPOS+=("${sid}=${url}")
  done
  if [[ ${#DECLARED_REPOS[@]} -eq 0 ]]; then
    echo "$(code2wiki_t cfg_err_need_one)" >&2
    exit 2
  fi
  BRANCH="$(code2wiki_prompt "$(code2wiki_t cfg_branch)" "$BRANCH")"
  VISIBILITY="$(code2wiki_prompt "$(code2wiki_t cfg_visibility)" "$VISIBILITY")"
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
  code2wiki_tf cfg_wrote "$dest"
  echo
}

# --- LLM full config (provider + URL + model + key); no OpenAI assumption ---
# Non-secret knobs always go to .env when provided (even with --skip-secrets).
# API key / GH / A2A files respect --skip-secrets.
configure_llm() {
  local provider="${LLM_PROVIDER_OPT:-}" base="${LLM_BASE_URL_OPT:-}" model="${LLM_MODEL_OPT:-}" key=""
  local write_key=1
  [[ "$SKIP_SECRETS" == 1 ]] && write_key=0

  if [[ -n "${LLM_API_KEY:-}" ]]; then
    key="$LLM_API_KEY"
  elif [[ -n "$LLM_KEY_FILE" && -r "$LLM_KEY_FILE" ]]; then
    key="$(tr -d '\r\n' <"$LLM_KEY_FILE")"
  fi

  if code2wiki_can_prompt && [[ "$NONINTERACTIVE" != 1 ]] && [[ "$SKIP_SECRETS" != 1 ]]; then
    echo "$(code2wiki_t cfg_llm_section)"
    provider="$(code2wiki_prompt "$(code2wiki_t cfg_llm_provider)" "$provider")"
    base="$(code2wiki_prompt "$(code2wiki_t cfg_llm_base_url)" "$base")"
    model="$(code2wiki_prompt "$(code2wiki_t cfg_llm_model)" "$model")"
    if [[ -z "$key" ]]; then
      key="$(code2wiki_prompt "$(code2wiki_t cfg_llm_key)")"
    fi
  fi

  # Nothing to write if user skipped entirely.
  if [[ -z "$provider" && -z "$model" && -z "$base" && -z "$key" ]]; then
    echo "$(code2wiki_t cfg_llm_skipped)"
    return 0
  fi

  # Persist non-secret knobs even when key is empty (user may fill secrets later).
  upsert_env LLM_PROVIDER "$provider"
  upsert_env LLM_BASE_URL "$base"
  upsert_env LLM_MODEL "$model"
  code2wiki_tf cfg_llm_wrote "$provider" "$model" "$base"
  echo

  if [[ "$write_key" == 1 && -n "$key" ]]; then
    write_secret secrets/llm_api_key "$key"
  fi
}

configure_llm

if [[ "$SKIP_SECRETS" != 1 ]]; then
  if [[ -n "${GH_TOKEN:-}" ]]; then
    write_secret secrets/gh_token "$GH_TOKEN"
  elif [[ -n "$GH_TOKEN_FILE" && -r "$GH_TOKEN_FILE" ]]; then
    write_secret secrets/gh_token "$(tr -d '\r\n' <"$GH_TOKEN_FILE")"
  elif code2wiki_can_prompt && [[ "$NONINTERACTIVE" != 1 ]]; then
    if [[ ! -s secrets/gh_token ]]; then
      tok="$(code2wiki_prompt "$(code2wiki_t cfg_gh_token)")"
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

echo "$(code2wiki_tf cfg_done "$PACK" "${#DECLARED_REPOS[@]}" "$OUT")"
echo "$(code2wiki_tf cfg_next "$PACK")"
