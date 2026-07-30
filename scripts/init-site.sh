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
mkdir -p "$SITE"/{profiles,secrets,runtime/{finclaw,hermes,answer-cache,data,bundles,logs,eval,examples},config,scripts,docs,templates}

cp "$TPL/docker-compose.yml" "$SITE/docker-compose.yml"
cp "$TPL/gitignore" "$SITE/.gitignore"
if [[ ! -f "$SITE/.env" || "$FORCE" == 1 ]]; then
  cp "$TPL/env.example" "$SITE/.env"
fi
cp "$TPL/secrets/README.md" "$SITE/secrets/README.md"
cp "$INTAKE/VERSION" "$SITE/VERSION"
cp "$INTAKE/docs/getting-started.md" "$SITE/docs/getting-started.md"
cp "$INTAKE/docs/calling.md" "$SITE/docs/calling.md"
cp "$INTAKE/docs/getting-started.zh.md" "$SITE/docs/getting-started.zh.md"
cp "$INTAKE/docs/calling.zh.md" "$SITE/docs/calling.zh.md"
if [[ -f "$INTAKE/README.zh.md" ]]; then
  cp "$INTAKE/README.zh.md" "$SITE/README.zh.md"
fi
if [[ -f "$TPL/secrets/README.zh.md" ]]; then
  cp "$TPL/secrets/README.zh.md" "$SITE/secrets/README.zh.md"
fi

# Host scripts (self-contained site)
SITE_SCRIPTS=(
  pull-image.sh up.sh down.sh doctor.sh ask.sh activate.sh exec.sh
  get-started.sh ingest.sh
  ensure-finclaw.sh configure-pack.sh materialize-caller.sh
  smoke-facade.sh setup-complete.sh
  ask-casst-a2a.sh ask-casst-mcp.sh run-setup-agent.sh
)
for s in "${SITE_SCRIPTS[@]}"; do
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
if [[ -f "$INTAKE/scripts/lib/pack_yaml.py" ]]; then
  cp "$INTAKE/scripts/lib/pack_yaml.py" "$SITE/scripts/lib/pack_yaml.py"
fi
if [[ -f "$INTAKE/scripts/lib/compose-env.sh" ]]; then
  cp "$INTAKE/scripts/lib/compose-env.sh" "$SITE/scripts/lib/compose-env.sh"
fi
if [[ -f "$INTAKE/scripts/lib/site-base-url.sh" ]]; then
  cp "$INTAKE/scripts/lib/site-base-url.sh" "$SITE/scripts/lib/site-base-url.sh"
fi
if [[ -f "$INTAKE/scripts/lib/prompt.sh" ]]; then
  cp "$INTAKE/scripts/lib/prompt.sh" "$SITE/scripts/lib/prompt.sh"
fi

# FinClaw caller templates (materialize into runtime/examples/ — never appliance homes)
mkdir -p "$SITE/templates/callers" "$SITE/runtime/examples"
if [[ -d "$TPL/callers" ]]; then
  cp -R "$TPL/callers/." "$SITE/templates/callers/"
fi

# Isolate Compose project from other sites / parent-shell leaks
if ! grep -q '^COMPOSE_PROJECT_NAME=' "$SITE/.env" 2>/dev/null; then
  echo "COMPOSE_PROJECT_NAME=casst-${PACK}" >>"$SITE/.env"
fi

PACK_DIR="$SITE/profiles/$PACK"
mkdir -p "$PACK_DIR"
if [[ ! -f "$PACK_DIR/sources.yaml" || "$FORCE" == 1 ]]; then
  cp "$TPL/profiles/_pack/sources.yaml" "$PACK_DIR/sources.yaml"
  cp "$TPL/profiles/_pack/retrieval-eval.yaml" "$PACK_DIR/retrieval-eval.yaml"
  cp "$TPL/profiles/_pack/product-wiki.md" "$PACK_DIR/product-wiki.md"
fi

# Bootstrap activated config so scrubber/ask work before the first activate.
mkdir -p "$SITE/config"
printf '%s\n' "$PACK" >"$SITE/config/active-profile"
{
  echo "# ACTIVE SOURCES — bootstrapped from profiles/${PACK}/sources.yaml"
  echo "# Re-run ./scripts/activate.sh ${PACK} after editing the pack."
  cat "$PACK_DIR/sources.yaml"
} >"$SITE/config/sources.yaml"
if grep -q '^CODE2WIKI_PROFILE=' "$SITE/.env" 2>/dev/null; then
  sed -i.bak "s/^CODE2WIKI_PROFILE=.*/CODE2WIKI_PROFILE=${PACK}/" "$SITE/.env" && rm -f "$SITE/.env.bak"
else
  echo "CODE2WIKI_PROFILE=${PACK}" >>"$SITE/.env"
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

English · [中文说明](docs/getting-started.zh.md)

## Guided (preferred)

From the intake repo (or after \`curl …/install.sh\`):

\`\`\`bash
# one-shot to SETUP_COMPLETE (non-interactive needs --repo):
# ./scripts/get-started.sh $SITE --pack $PACK --repo <id>=<git-url>
\`\`\`

On this site after a manual init, finish with:

\`\`\`bash
./scripts/configure-pack.sh --pack $PACK --repo <id>=<git-url>
./scripts/pull-image.sh && ./scripts/up.sh && ./scripts/doctor.sh
./scripts/activate.sh $PACK && ./scripts/ingest.sh
./scripts/setup-complete.sh   # REST + A2A + FinClaw callers → SETUP_COMPLETE
\`\`\`

## Manual checklist

1. Edit \`profiles/$PACK/sources.yaml\` and \`retrieval-eval.yaml\` (or use configure-pack)
2. Fill \`secrets/llm_api_key\` (and \`gh_token\` if remotes are private)
3. Set \`CODE2WIKI_IMAGE\` in \`.env\` if dogfooding a local tag (e.g. \`code2wiki:dev\`)
4. \`./scripts/pull-image.sh && ./scripts/up.sh && ./scripts/doctor.sh\`
5. \`./scripts/activate.sh $PACK\`
6. \`./scripts/ingest.sh\`
7. \`./scripts/ask.sh "Your first question" --product <source-id>\`
8. \`./scripts/setup-complete.sh\` (optional FinClaw A2A/MCP smokes)

See \`docs/getting-started.md\` / \`docs/getting-started.zh.md\`.
EOF

echo "initialized site: $SITE"
echo "pack:             profiles/$PACK"
echo "next:             ./scripts/configure-pack.sh --pack $PACK --repo id=url"
echo "                  then ./scripts/get-started.sh $SITE --pack $PACK --skip-configure"
echo "                  or continue: pull → up → activate → ingest → setup-complete"
