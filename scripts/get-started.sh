#!/usr/bin/env bash
# Guided path: init → FinClaw → configure pack → up → activate → ingest → SETUP_COMPLETE.
#
# Interactive (TTY / curl|sh via /dev/tty):
#   ./scripts/get-started.sh
#   # prompts: site dir, pack id, then Git remotes + secrets
#
# Non-interactive / CI:
#   ./scripts/get-started.sh --site ~/casst-site --pack acme \
#     --repo my-app=https://github.com/org/app.git
#
# Locale: auto from LANG / LC_* ; override with CODE2WIKI_LANG=en|zh or --lang.
#
# Flags:
#   --site DIR      site directory (or pass as first positional arg)
#   --pack ID
#   --repo id=url   (repeatable; skips interactive repo prompts when provided)
#   --lang en|zh
#   --mock          CASST_MOCK=1
#   --skip-finclaw  do not install FinClaw (still required for caller smokes unless --skip-caller)
#   --skip-caller   skip FinClaw A2A/MCP caller checks in setup-complete
#   --skip-configure  assume pack already configured
#   --no-up         stop after configure (print next steps)
#   --agent         after site is up, launch FinClaw setup profile chat
#   --force         pass --force to init-site
set -euo pipefail

INTAKE="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$INTAKE/scripts/lib/prompt.sh"
# shellcheck disable=SC1091
source "$INTAKE/scripts/lib/i18n.sh"
# shellcheck disable=SC1091
source "$INTAKE/scripts/lib/progress.sh"

SITE=""
PACK=""
MOCK=0
SKIP_FINCLAW=0
SKIP_CALLER=0
SKIP_CONFIGURE=0
NO_UP=0
AGENT=0
FORCE=0
REPOS=()
BRANCH="main"
TOTAL_STEPS=10

usage() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --site) SITE="${2:-}"; shift 2 ;;
    --pack) PACK="${2:-}"; shift 2 ;;
    --repo) REPOS+=("$2"); shift 2 ;;
    --branch) BRANCH="${2:-main}"; shift 2 ;;
    --lang) CODE2WIKI_LANG="${2:-}"; shift 2 ;;
    --mock) MOCK=1; shift ;;
    --skip-finclaw) SKIP_FINCLAW=1; shift ;;
    --skip-caller) SKIP_CALLER=1; shift ;;
    --skip-configure) SKIP_CONFIGURE=1; shift ;;
    --no-up) NO_UP=1; shift ;;
    --agent) AGENT=1; shift ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      if [[ -z "$SITE" && "$1" != -* ]]; then SITE="$1"; shift
      else echo "error: unexpected $1" >&2; exit 2
      fi
      ;;
  esac
done

code2wiki_i18n_init

# --- Interactive defaults (works under curl|sh via /dev/tty) ---
if [[ -z "$SITE" ]]; then
  if code2wiki_can_prompt; then
    echo "$(code2wiki_t banner_setup)"
    code2wiki_tf lang_note "$CODE2WIKI_UI_LANG"
    echo
    SITE="$(code2wiki_prompt "$(code2wiki_t site_prompt)" "${CODE2WIKI_SITE:-$HOME/casst-site}")"
  else
    echo "$(code2wiki_t err_site_required)" >&2
    usage
    exit 2
  fi
fi
SITE="$(code2wiki_expand_path "$SITE")"
# Refuse to create a literal "~" directory (failed / unexpanded home).
if [[ "$SITE" == '~' || "$SITE" == '~/'* || "$SITE" == '~\'* || "$SITE" == */'~' || "$SITE" == */'~/'* || "$SITE" == */'~\'* ]]; then
  code2wiki_tf err_site_tilde "$SITE" >&2
  echo "$(code2wiki_t hint_site_path)" >&2
  exit 2
fi
code2wiki_tf site_resolved "$SITE"
echo

if [[ -z "$PACK" ]]; then
  if code2wiki_can_prompt && [[ ${#REPOS[@]} -eq 0 || -z "${CODE2WIKI_PROFILE:-}" ]]; then
    PACK="$(code2wiki_prompt "$(code2wiki_t pack_prompt)" "${CODE2WIKI_PROFILE:-acme}")"
  else
    PACK="${CODE2WIKI_PROFILE:-acme}"
  fi
fi

if [[ ! "$PACK" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]]; then
  code2wiki_tf err_pack_invalid "$PACK" >&2
  exit 2
fi

code2wiki_step 1 "$TOTAL_STEPS" step_init
INIT_ARGS=("$SITE" --pack "$PACK")
[[ "$FORCE" == 1 ]] && INIT_ARGS+=(--force)
"$INTAKE/scripts/init-site.sh" "${INIT_ARGS[@]}"
SITE="$(cd "$SITE" && pwd)"
cd "$SITE"
if [[ -f runtime/.finclaw-env ]]; then
  # shellcheck disable=SC1091
  source runtime/.finclaw-env
fi

# Isolate compose + pick a free host port when the default is busy.
ensure_site_network() {
  local port want
  if ! grep -q '^COMPOSE_PROJECT_NAME=' .env 2>/dev/null; then
    echo "COMPOSE_PROJECT_NAME=casst-${PACK}" >>.env
  fi
  port="$(grep -E '^CODE2WIKI_PORT=' .env 2>/dev/null | cut -d= -f2- || true)"
  port="${port:-8080}"
  want="$port"
  if ! python3 - "$port" <<'PY'
import socket, sys
p = int(sys.argv[1])
s = socket.socket()
try:
    s.bind(("0.0.0.0", p))
except OSError:
    raise SystemExit(1)
finally:
    s.close()
raise SystemExit(0)
PY
  then
    for try in 18080 18081 18082 18083 18084 28080; do
      if python3 - "$try" <<'PY'
import socket, sys
p = int(sys.argv[1])
s = socket.socket()
try:
    s.bind(("0.0.0.0", p))
except OSError:
    raise SystemExit(1)
finally:
    s.close()
raise SystemExit(0)
PY
      then
        want="$try"
        break
      fi
    done
    if [[ "$want" == "$port" ]]; then
      code2wiki_tf err_port_busy "$port" >&2
      exit 1
    fi
    code2wiki_tf port_busy "$port" "$want"
    if grep -q '^CODE2WIKI_PORT=' .env; then
      sed -i.bak "s/^CODE2WIKI_PORT=.*/CODE2WIKI_PORT=${want}/" .env && rm -f .env.bak
    else
      echo "CODE2WIKI_PORT=${want}" >>.env
    fi
    if grep -q '^CASST_PUBLIC_BASE_URL=' .env; then
      sed -i.bak "s|^CASST_PUBLIC_BASE_URL=.*|CASST_PUBLIC_BASE_URL=http://127.0.0.1:${want}|" .env && rm -f .env.bak
    else
      echo "CASST_PUBLIC_BASE_URL=http://127.0.0.1:${want}" >>.env
    fi
  fi
}

code2wiki_step 2 "$TOTAL_STEPS" step_network
ensure_site_network

if [[ "$MOCK" == 1 ]]; then
  if grep -q '^CASST_MOCK=' .env; then
    sed -i.bak 's/^CASST_MOCK=.*/CASST_MOCK=1/' .env && rm -f .env.bak
  else
    echo 'CASST_MOCK=1' >>.env
  fi
  echo "$(code2wiki_t mock_enabled)"
fi

code2wiki_step 3 "$TOTAL_STEPS" step_finclaw
if [[ "$SKIP_FINCLAW" == 1 ]]; then
  ./scripts/ensure-finclaw.sh --skip || true
else
  ./scripts/ensure-finclaw.sh
fi

code2wiki_step 4 "$TOTAL_STEPS" step_configure
if [[ "$SKIP_CONFIGURE" != 1 ]]; then
  cfg=(--pack "$PACK" --branch "$BRANCH")
  if [[ ${#REPOS[@]} -gt 0 ]]; then
    for r in "${REPOS[@]}"; do cfg+=(--repo "$r"); done
    cfg+=(--non-interactive)
    ./scripts/configure-pack.sh "${cfg[@]}"
  elif code2wiki_can_prompt; then
    ./scripts/configure-pack.sh --pack "$PACK" --branch "$BRANCH"
  else
    echo "$(code2wiki_t err_repo_required)" >&2
    exit 2
  fi
else
  echo "$(code2wiki_t skip_configure)"
fi

if [[ "$NO_UP" == 1 ]]; then
  echo
  code2wiki_tf site_configured "$SITE"
  echo "$(code2wiki_t next_steps)"
  cat <<EOF
  ./scripts/pull-image.sh && ./scripts/up.sh && ./scripts/doctor.sh
  ./scripts/activate.sh $PACK && ./scripts/ingest.sh
  ./scripts/setup-complete.sh
EOF
  exit 0
fi

code2wiki_step 5 "$TOTAL_STEPS" step_pull
./scripts/pull-image.sh

code2wiki_step 6 "$TOTAL_STEPS" step_up
./scripts/up.sh

PORT="$(grep -E '^CODE2WIKI_PORT=' .env 2>/dev/null | cut -d= -f2- || true)"
PORT="${PORT:-8080}"
BASE="http://127.0.0.1:${PORT}"
code2wiki_step 7 "$TOTAL_STEPS" step_health
code2wiki_tf waiting_health "$BASE"
if code2wiki_wait_http "${BASE}/healthz" 120; then
  code2wiki_tf healthy_after "${CODE2WIKI_WAIT_ELAPSED:-0}"
else
  echo "$(code2wiki_t err_not_healthy)" >&2
  ./scripts/doctor.sh || true
  exit 1
fi

./scripts/doctor.sh

code2wiki_step 8 "$TOTAL_STEPS" step_activate
./scripts/activate.sh "$PACK"

code2wiki_step 9 "$TOTAL_STEPS" step_ingest
./scripts/ingest.sh

code2wiki_step 10 "$TOTAL_STEPS" step_complete
COMPLETE_ARGS=()
[[ "$SKIP_CALLER" == 1 || "$SKIP_FINCLAW" == 1 ]] && COMPLETE_ARGS+=(--skip-finclaw-caller)
[[ "$MOCK" == 1 ]] && COMPLETE_ARGS+=(--no-chat)
./scripts/setup-complete.sh "${COMPLETE_ARGS[@]+"${COMPLETE_ARGS[@]}"}"

if [[ "$AGENT" == 1 ]]; then
  echo "$(code2wiki_t launch_agent)"
  ./scripts/run-setup-agent.sh || true
fi

echo
code2wiki_tf done "$SITE"
