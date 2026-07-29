#!/usr/bin/env sh
# Bootstrap the public intake onto this machine, then init a site.
#
#   curl -fsSL https://raw.githubusercontent.com/finogeeks/code2wiki/main/install.sh | sh
#   curl -fsSL .../install.sh | sh -s -- --site ~/casst-site --pack acme
#
# Until the public GitHub repo exists, run from a local checkout:
#   sh install.sh --site ~/casst-site --pack acme
set -eu

SITE="${CODE2WIKI_SITE:-$HOME/casst-site}"
PACK="${CODE2WIKI_PACK:-acme}"
INTAKE_DIR="${CODE2WIKI_INTAKE_DIR:-}"
REPO="${CODE2WIKI_PUBLIC_REPO:-finogeeks/code2wiki}"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --site) SITE="$2"; shift 2 ;;
    --pack) PACK="$2"; shift 2 ;;
    --intake-dir) INTAKE_DIR="$2"; shift 2 ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$INTAKE_DIR" ]; then
  # Prefer running from a checkout that already contains scripts/init-site.sh
  HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
  if [ -x "$HERE/scripts/init-site.sh" ]; then
    INTAKE_DIR="$HERE"
  else
    INTAKE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/code2wiki-intake"
    if [ ! -x "$INTAKE_DIR/scripts/init-site.sh" ]; then
      if command -v git >/dev/null 2>&1; then
        mkdir -p "$(dirname "$INTAKE_DIR")"
        if [ -d "$INTAKE_DIR/.git" ]; then
          git -C "$INTAKE_DIR" pull --ff-only || true
        else
          git clone "https://github.com/${REPO}.git" "$INTAKE_DIR"
        fi
      else
        echo "error: need git to clone $REPO, or pass --intake-dir" >&2
        exit 1
      fi
    fi
  fi
fi

exec "$INTAKE_DIR/scripts/get-started.sh" "$SITE" --pack "$PACK"
