#!/usr/bin/env sh
# Bootstrap public intake, then run the guided get-started path.
#
# Interactive (recommended — no flags needed):
#   curl -fsSL https://raw.githubusercontent.com/finogeeks/code2wiki/main/install.sh | sh
#
# Non-interactive / CI:
#   curl -fsSL …/install.sh | sh -s -- --site ~/casst-site --pack acme \
#     --repo my-app=https://github.com/org/app.git
#
# All flags except --intake-dir / --help are forwarded to get-started.sh
# (including --site, --pack, --repo).
set -eu

INTAKE_DIR="${CODE2WIKI_INTAKE_DIR:-}"
REPO="${CODE2WIKI_PUBLIC_REPO:-finogeeks/code2wiki}"
BRANCH="${CODE2WIKI_PUBLIC_BRANCH:-main}"
FORWARD=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --intake-dir)
      INTAKE_DIR="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      # Require simple tokens (no spaces in values). Prefer interactive for complex input.
      FORWARD="$FORWARD $1"
      shift
      ;;
  esac
done

# Refresh the disposable XDG intake cache to origin/$BRANCH (not a user workspace).
# Always fetch+reset: a previous bug only updated when the cache was missing, so
# curl|sh kept serving stale get-started/prompt after public syncs.
refresh_intake_cache() {
  dir="$1"
  if ! command -v git >/dev/null 2>&1; then
    echo "error: need git to clone $REPO, or pass --intake-dir" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$dir")"
  if [ ! -d "$dir/.git" ]; then
    rm -rf "$dir"
    git clone --branch "$BRANCH" --single-branch \
      "https://github.com/${REPO}.git" "$dir"
  else
    git -C "$dir" remote set-url origin "https://github.com/${REPO}.git"
    git -C "$dir" fetch --depth 1 origin "$BRANCH"
    git -C "$dir" checkout -B "$BRANCH" "origin/$BRANCH"
    git -C "$dir" reset --hard "origin/$BRANCH"
    git -C "$dir" clean -fd
  fi
  if [ ! -x "$dir/scripts/init-site.sh" ]; then
    echo "error: intake at $dir is missing scripts/init-site.sh" >&2
    exit 1
  fi
  echo "install: intake $(git -C "$dir" rev-parse --short HEAD) ($REPO@$BRANCH)"
}

if [ -z "$INTAKE_DIR" ]; then
  HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
  if [ -x "$HERE/scripts/init-site.sh" ]; then
    # Running from a full intake checkout (dev / already cloned).
    INTAKE_DIR="$HERE"
  else
    INTAKE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/code2wiki-intake"
    refresh_intake_cache "$INTAKE_DIR"
  fi
fi

# shellcheck disable=SC2086
exec "$INTAKE_DIR/scripts/get-started.sh" $FORWARD
