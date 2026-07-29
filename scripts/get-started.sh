#!/usr/bin/env bash
# Guided customer path: init-site → remind edits → pull → up → doctor.
#
# Usage:
#   ./scripts/get-started.sh ~/casst-site --pack acme
#   ./scripts/get-started.sh ~/casst-site --pack acme --mock   # CASST_MOCK=1
set -euo pipefail

INTAKE="$(cd "$(dirname "$0")/.." && pwd)"
SITE=""
PACK="acme"
MOCK=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pack) PACK="${2:-}"; shift 2 ;;
    --mock) MOCK=1; shift ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      if [[ -z "$SITE" ]]; then SITE="$1"; shift
      else echo "error: unexpected $1" >&2; exit 2
      fi
      ;;
  esac
done
[[ -n "$SITE" ]] || { echo "usage: get-started.sh <site-dir> [--pack id] [--mock]" >&2; exit 2; }

"$INTAKE/scripts/init-site.sh" "$SITE" --pack "$PACK"
SITE="$(cd "$SITE" && pwd)"
cd "$SITE"

if [[ "$MOCK" == 1 ]]; then
  if grep -q '^CASST_MOCK=' .env; then
    sed -i.bak 's/^CASST_MOCK=.*/CASST_MOCK=1/' .env && rm -f .env.bak
  else
    echo 'CASST_MOCK=1' >>.env
  fi
  echo "CASST_MOCK=1 enabled (plumbing smoke; answers are echoes)"
fi

cat <<EOF

== site ready: $SITE ==

Before up/activate, edit:
  profiles/$PACK/sources.yaml
  profiles/$PACK/retrieval-eval.yaml
  secrets/llm_api_key   (optional if CASST_MOCK=1)
  secrets/gh_token      (if private remotes)

Then:
  ./scripts/pull-image.sh
  ./scripts/up.sh
  ./scripts/doctor.sh
  ./scripts/activate.sh $PACK
  ./scripts/ask.sh "What sources are registered?"

Optional FinClaw/Hermes callers: docs/calling.md
EOF

if [[ "${GET_STARTED_AUTO_UP:-0}" == "1" ]]; then
  ./scripts/pull-image.sh
  ./scripts/up.sh
  sleep 3
  ./scripts/doctor.sh || true
fi
