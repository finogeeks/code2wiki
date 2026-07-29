#!/usr/bin/env bash
# Create a host-side casst site directory (pack + secrets + runtime + compose).
#
# Usage:
#   ./scripts/init-site.sh ~/casst-site --pack acme
#   ./scripts/init-site.sh ~/casst-site --pack acme --force
set -euo pipefail

INTAKE="$(cd "$(dirname "$0")/.." && pwd)"
SITE=""
PACK="acme"
FORCE=0

usage() {
  sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --pack)
      PACK="${2:-}"; [[ -n "$PACK" ]] || { echo "error: --pack needs id" >&2; exit 2; }
      shift 2
      ;;
    --force) FORCE=1; shift ;;
    *)
      if [[ -z "$SITE" ]]; then SITE="$1"; shift
      else echo "error: unexpected arg: $1" >&2; exit 2
      fi
      ;;
  esac
done

[[ -n "$SITE" ]] || { usage; exit 2; }
if [[ ! "$PACK" =~ ^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$ ]]; then
  echo "error: invalid pack id: $PACK" >&2
  exit 2
fi

SITE="$(mkdir -p "$SITE" && cd "$SITE" && pwd)"
if [[ -f "$SITE/docker-compose.yml" && "$FORCE" != 1 ]]; then
  echo "error: $SITE already looks initialized (pass --force to refresh templates)" >&2
  exit 1
fi

TPL="$INTAKE/templates"
mkdir -p "$SITE"/{profiles,secrets,runtime/{finclaw,hermes,answer-cache,data,bundles,logs,eval},config,scripts,docs}

cp "$TPL/docker-compose.yml" "$SITE/docker-compose.yml"
cp "$TPL/gitignore" "$SITE/.gitignore"
if [[ ! -f "$SITE/.env" || "$FORCE" == 1 ]]; then
  cp "$TPL/env.example" "$SITE/.env"
fi
cp "$TPL/secrets/README.md" "$SITE/secrets/README.md"
cp "$INTAKE/VERSION" "$SITE/VERSION"
cp "$INTAKE/docs/getting-started.md" "$SITE/docs/getting-started.md"
cp "$INTAKE/docs/calling.md" "$SITE/docs/calling.md"

# Host scripts (self-contained site)
for s in pull-image.sh up.sh down.sh doctor.sh ask.sh activate.sh exec.sh get-started.sh; do
  if [[ -f "$INTAKE/scripts/$s" ]]; then
    cp "$INTAKE/scripts/$s" "$SITE/scripts/$s"
    chmod +x "$SITE/scripts/$s"
  fi
done
# Keep a copy of init-site for re-runs from the site (optional)
cp "$INTAKE/scripts/init-site.sh" "$SITE/scripts/init-site.sh"
chmod +x "$SITE/scripts/init-site.sh"
# Site-local lib
mkdir -p "$SITE/scripts/lib"
cat > "$SITE/scripts/lib/site-root.sh" <<'EOF'
# shellcheck shell=bash
site_root() {
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[1]}")/.." && pwd)"
  echo "$here"
}
EOF

PACK_DIR="$SITE/profiles/$PACK"
mkdir -p "$PACK_DIR"
if [[ ! -f "$PACK_DIR/sources.yaml" || "$FORCE" == 1 ]]; then
  cp "$TPL/profiles/_pack/sources.yaml" "$PACK_DIR/sources.yaml"
  cp "$TPL/profiles/_pack/retrieval-eval.yaml" "$PACK_DIR/retrieval-eval.yaml"
  cp "$TPL/profiles/_pack/product-wiki.md" "$PACK_DIR/product-wiki.md"
fi

umask 077
for name in gh_token llm_api_key a2a_peer_token; do
  path="$SITE/secrets/$name"
  if [[ ! -e "$path" ]]; then
    : >"$path"
    chmod 600 "$path"
  fi
done

# Pin image from VERSION when not overridden
VER="$(tr -d '[:space:]' < "$SITE/VERSION")"
if [[ "$VER" != "0.0.0-dev" && -n "$VER" ]]; then
  if ! grep -q '^CODE2WIKI_IMAGE=' "$SITE/.env" 2>/dev/null; then
    echo "CODE2WIKI_IMAGE=ghcr.io/finogeeks/code2wiki:${VER}" >>"$SITE/.env"
  fi
fi

cat > "$SITE/README.md" <<EOF
# casst site

Pack: \`$PACK\`

1. Edit \`profiles/$PACK/sources.yaml\` and \`retrieval-eval.yaml\`
2. Fill \`secrets/llm_api_key\` (and \`gh_token\` if remotes are private)
3. \`./scripts/pull-image.sh && ./scripts/up.sh\`
4. \`./scripts/activate.sh $PACK\`
5. \`./scripts/ask.sh "Your first question"\`

See \`docs/getting-started.md\`.
EOF

echo "initialized site: $SITE"
echo "pack:             profiles/$PACK"
echo "next:             edit sources + secrets, then ./scripts/pull-image.sh && ./scripts/up.sh"
