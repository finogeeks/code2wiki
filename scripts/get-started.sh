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
# Flags:
#   --site DIR      site directory (or pass as first positional arg)
#   --pack ID
#   --repo id=url   (repeatable; skips interactive repo prompts when provided)
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

usage() {
  sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --site) SITE="${2:-}"; shift 2 ;;
    --pack) PACK="${2:-}"; shift 2 ;;
    --repo) REPOS+=("$2"); shift 2 ;;
    --branch) BRANCH="${2:-main}"; shift 2 ;;
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

# --- Interactive defaults (works under curl|sh via /dev/tty) ---
if [[ -z "$SITE" ]]; then
  if code2wiki_can_prompt; then
    echo "code2wiki get-started — interactive setup"
    SITE="$(code2wiki_prompt "Site directory" "${CODE2WIKI_SITE:-$HOME/casst-site}")"
  else
    echo "error: --site DIR required in non-interactive mode" >&2
    usage
    exit 2
  fi
fi
SITE="$(code2wiki_expand_path "$SITE")"
# Refuse to create a literal "~" directory (failed / unexpanded home).
if [[ "$SITE" == '~' || "$SITE" == '~/'* || "$SITE" == '~\'* || "$SITE" == */'~' || "$SITE" == */'~/'* || "$SITE" == */'~\'* ]]; then
  echo "error: site path still contains an unexpanded '~': $SITE" >&2
  echo "hint: use an absolute path, or ~/dir / \$HOME/dir" >&2
  exit 2
fi
echo "get-started: site → $SITE"

if [[ -z "$PACK" ]]; then
  if code2wiki_can_prompt && [[ ${#REPOS[@]} -eq 0 || -z "${CODE2WIKI_PROFILE:-}" ]]; then
    PACK="$(code2wiki_prompt "Pack id (short name for this product)" "${CODE2WIKI_PROFILE:-acme}")"
  else
    PACK="${CODE2WIKI_PROFILE:-acme}"
  fi
fi

if [[ ! "$PACK" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]]; then
  echo "error: invalid pack id: $PACK" >&2
  exit 2
fi

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
      echo "error: host port ${port} is busy; set CODE2WIKI_PORT in .env" >&2
      exit 1
    fi
    echo "get-started: port ${port} busy → using ${want}"
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
ensure_site_network

if [[ "$MOCK" == 1 ]]; then
  if grep -q '^CASST_MOCK=' .env; then
    sed -i.bak 's/^CASST_MOCK=.*/CASST_MOCK=1/' .env && rm -f .env.bak
  else
    echo 'CASST_MOCK=1' >>.env
  fi
  echo "CASST_MOCK=1 enabled"
fi

# --- FinClaw ---
if [[ "$SKIP_FINCLAW" == 1 ]]; then
  ./scripts/ensure-finclaw.sh --skip || true
else
  ./scripts/ensure-finclaw.sh
fi

# --- Pack configure ---
if [[ "$SKIP_CONFIGURE" != 1 ]]; then
  cfg=(--pack "$PACK" --branch "$BRANCH")
  if [[ ${#REPOS[@]} -gt 0 ]]; then
    for r in "${REPOS[@]}"; do cfg+=(--repo "$r"); done
    cfg+=(--non-interactive)
    ./scripts/configure-pack.sh "${cfg[@]}"
  elif code2wiki_can_prompt; then
    ./scripts/configure-pack.sh --pack "$PACK" --branch "$BRANCH"
  else
    echo "error: non-interactive get-started requires --repo id=url (repeatable)" >&2
    exit 2
  fi
else
  echo "get-started: skipping configure-pack"
fi

if [[ "$NO_UP" == 1 ]]; then
  cat <<EOF
== site configured: $SITE ==
Next:
  ./scripts/pull-image.sh && ./scripts/up.sh && ./scripts/doctor.sh
  ./scripts/activate.sh $PACK && ./scripts/ingest.sh
  ./scripts/setup-complete.sh
EOF
  exit 0
fi

# --- Appliance up ---
./scripts/pull-image.sh
./scripts/up.sh
# Wait for healthz
PORT="$(grep -E '^CODE2WIKI_PORT=' .env 2>/dev/null | cut -d= -f2- || true)"
PORT="${PORT:-8080}"
BASE="http://127.0.0.1:${PORT}"
echo "get-started: waiting for ${BASE}/healthz …"
for i in $(seq 1 60); do
  if curl -fsS --max-time 2 "${BASE}/healthz" >/dev/null 2>&1; then
    echo "get-started: healthy after ${i}s"
    break
  fi
  sleep 2
  if [[ "$i" -eq 60 ]]; then
    echo "error: facade did not become healthy" >&2
    ./scripts/doctor.sh || true
    exit 1
  fi
done

./scripts/doctor.sh
./scripts/activate.sh "$PACK"
./scripts/ingest.sh

COMPLETE_ARGS=()
[[ "$SKIP_CALLER" == 1 || "$SKIP_FINCLAW" == 1 ]] && COMPLETE_ARGS+=(--skip-finclaw-caller)
[[ "$MOCK" == 1 ]] && COMPLETE_ARGS+=(--no-chat)
./scripts/setup-complete.sh "${COMPLETE_ARGS[@]+"${COMPLETE_ARGS[@]}"}"

if [[ "$AGENT" == 1 ]]; then
  echo "get-started: launching FinClaw setup agent (optional polish / Q&A)"
  ./scripts/run-setup-agent.sh || true
fi

echo "get-started: done → $SITE"
