# code2wiki (public intake)

English | [中文](README.zh.md)

**casst** appliance for answering from *your* product git repositories.

This repository is the **customer intake**: host scripts, compose template, and
docs. The runtime is a **Docker image** (`ghcr.io/finogeeks/code2wiki`). You do
not build from this tree.

> Publishing from the private monorepo to GHCR + this repo is a follow-up.
> For local dogfood, set `CODE2WIKI_IMAGE=code2wiki:dev` after building the
> private checkout.

## Quick start

```bash
# From this repo (or after curl install.sh):
./scripts/init-site.sh ~/casst-site --pack acme
cd ~/casst-site

# 1) Edit pack + secrets
$EDITOR profiles/acme/sources.yaml
$EDITOR profiles/acme/retrieval-eval.yaml
printf '%s' 'your-llm-key' > secrets/llm_api_key
printf '%s' 'your-gh-pat'  > secrets/gh_token   # if private remotes

# 2) Pull image + start facade
./scripts/pull-image.sh
./scripts/up.sh

# 3) Activate pack + smoke REST ask (no FinClaw caller required)
./scripts/activate.sh acme
./scripts/ask.sh "What repositories does this appliance answer from?"
```

Guided path: `./scripts/get-started.sh ~/casst-site --pack acme`

## What gets created

| Path | Purpose |
|------|---------|
| `profiles/<pack>/` | Your sources + retrieval-eval stubs |
| `secrets/` | `llm_api_key`, `gh_token`, `a2a_peer_token` (mode 600) |
| `runtime/` | FinClaw/Hermes homes, answer-cache, logs, eval |
| `config/` | Activated pack pointer (written by `activate.sh`) |
| `.env` | Non-secret knobs |
| `docker-compose.yml` | Runs the published image with bind mounts |

## First success = REST

FinClaw / Hermes as *callers* are optional. See [docs/calling.md](docs/calling.md)
([中文](docs/calling.zh.md)).

## Docs

- [docs/getting-started.md](docs/getting-started.md) ([中文](docs/getting-started.zh.md))
- [docs/calling.md](docs/calling.md) ([中文](docs/calling.zh.md))
