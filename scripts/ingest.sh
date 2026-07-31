#!/usr/bin/env bash
# Clone/update registered remotes into the appliance mirror store and warm
# the answer cache when cold. Run after activate, before expecting grounded asks.
#
# Usage:
#   ./scripts/ingest.sh                 # all sources; warm if cache cold
#   ./scripts/ingest.sh --source acme   # one source id
#   ./scripts/ingest.sh --warm          # force wiki warm for changed sources
#   ./scripts/ingest.sh --no-bootstrap  # skip day-1 ledger stubs (when image has them)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/compose-env.sh"
code2wiki_compose_env "$ROOT"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/docker-runtime.sh"
# shellcheck disable=SC1091
source "$ROOT/scripts/lib/appliance-runtime.sh"

RECONCILE_ARGS=(--warm-if-cold --json)
BOOTSTRAP=1
SOURCE_FILTER=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      [[ -n "${2:-}" ]] || { echo "error: --source needs an id" >&2; exit 2; }
      RECONCILE_ARGS+=(--source "$2")
      SOURCE_FILTER+=(--source "$2")
      shift 2
      ;;
    --warm)
      RECONCILE_ARGS=(--warm --json)
      shift
      ;;
    --dry-run)
      RECONCILE_ARGS+=(--dry-run)
      shift
      ;;
    --no-bootstrap)
      BOOTSTRAP=0
      shift
      ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "error: unexpected arg: $1" >&2
      exit 2
      ;;
  esac
done

LEDGER_ENV=(
  -e CODE2WIKI_DATA=/var/lib/code2wiki/data
  -e ANSWER_CACHE=/var/lib/code2wiki/answer-cache
  -e WIKI_WORKSPACE=/var/lib/code2wiki/answer-cache
  -e "CASST_LEDGER_ROOT=${CASST_LEDGER_ROOT:-/var/lib/code2wiki/answer-cache/wiki/capabilities}"
)

echo "ingest: prepare corpus link paths"
code2wiki_appliance_exec bash -lc '
set -euo pipefail
mkdir -p /workspace/code2wiki/runtime/data
ln -sfn /var/lib/code2wiki/data/mirrors /workspace/code2wiki/runtime/data/mirrors
'

echo "ingest: reconcile remotes → /var/lib/code2wiki/data/mirrors"
code2wiki_appliance_exec "${LEDGER_ENV[@]}" \
  ./scripts/reconcile-sources.py "${RECONCILE_ARGS[@]}"

echo "ingest: link corpus"
code2wiki_appliance_exec "${LEDGER_ENV[@]}" ./scripts/casst-link-corpus.sh

if [[ "${BOOTSTRAP}" == "1" ]]; then
  echo "ingest: bootstrap capability stubs (no-op if image lacks helper or pages exist)"
  code2wiki_appliance_exec "${LEDGER_ENV[@]}" \
    bash -lc '[[ -f ./scripts/bootstrap-capability-stubs.py ]] || { echo "[bootstrap] skip: helper not in this image yet"; exit 0; }; exec ./scripts/bootstrap-capability-stubs.py "$@"' \
    _ "${SOURCE_FILTER[@]}"
fi

echo "ingest: done — next: ./scripts/ask.sh \"Your question\" --product <source-id>"
