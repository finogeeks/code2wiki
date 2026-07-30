# Getting started

English | [中文](getting-started.zh.md)

## Prerequisites

- Docker + Compose v2
- An LLM API key (for real answers; `CASST_MOCK=1` works for plumbing smoke)
- Git remotes you are allowed to clone (public HTTPS or a PAT in `secrets/gh_token`)
- A code2wiki image: published `ghcr.io/finogeeks/code2wiki:<ver>`, **or** a local
  dogfood tag such as `code2wiki:dev` (set `CODE2WIKI_IMAGE` in `.env`)
- Optional: host [FinClaw CLI](https://github.com/finogeeks/finclaw-cli) for A2A/MCP
  caller smokes (`./scripts/ensure-finclaw.sh` installs it)

## Guided path (recommended)

**No clone, no flags** — run in a terminal; prompts ask for site, pack, remotes:

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/code2wiki/main/install.sh | sh
```

From an existing intake checkout (also interactive by default):

```bash
./scripts/get-started.sh
```

CI / non-interactive (all required args explicit):

```bash
./scripts/get-started.sh --site ~/casst-site --pack acme \
  --repo my-app=https://github.com/org/app.git
```

Useful flags: `--mock`, `--skip-finclaw`, `--skip-caller`, `--agent` (FinClaw
setup chat after complete), `--force`, `--no-up` (stop after configure).

Success means `runtime/eval/SETUP_COMPLETE.json` exists and the banner prints
`SETUP_COMPLETE`. Then jump to [§7 Operator console](#7-operator-console-see-live-traffic-signals).

## Manual steps

### 1. Create a site directory

```bash
./scripts/init-site.sh ~/casst-site --pack acme
cd ~/casst-site
```

If another appliance already binds host `:8080`, edit `.env`:

```bash
CODE2WIKI_PORT=18080
CASST_PUBLIC_BASE_URL=http://127.0.0.1:18080
# optional when multiple sites share one Docker daemon:
# COMPOSE_PROJECT_NAME=casst-acme
```

### 2. Configure the pack

Prefer the helper (writes YAML + optional secrets):

```bash
./scripts/configure-pack.sh --pack acme \
  --repo my-app=https://github.com/org/app.git
# interactive TTY also works without --repo
```

Or edit `profiles/acme/sources.yaml` by hand. Keep `visibility: private` unless
the corpus is intentionally public. Use `expect_sources: [your-source-id]` in
`retrieval-eval.yaml` (not `expect_source_ids`).

### 3. Secrets

```bash
printf '%s' 'sk-…' > secrets/llm_api_key
printf '%s' 'ghp-…' > secrets/gh_token   # if needed
chmod 600 secrets/*
```

`configure-pack` can mint `secrets/a2a_peer_token` when empty. Optional: set
`LLM_PROVIDER` / `LLM_MODEL` / `LLM_BASE_URL` in `.env`.

### 4. Image + up

```bash
# Local dogfood (GHCR publish is still a follow-up):
# echo 'CODE2WIKI_IMAGE=code2wiki:dev' >> .env

./scripts/pull-image.sh          # uses CODE2WIKI_IMAGE / VERSION
./scripts/up.sh                  # facade on CODE2WIKI_PORT (default :8080)
./scripts/doctor.sh              # /healthz
```

### 5. Activate + ingest (required for grounded answers)

```bash
./scripts/activate.sh acme

# Clone remotes into the appliance mirror store and warm the knowledge cache.
# Skipping this leaves corpus-link empty and asks poorly grounded.
# Newer images also seed a README overview stub when a product has no ledger pages.
./scripts/ingest.sh
# or: ./scripts/ingest.sh --source <id>

# optional routing gate (needs retrieval-eval filled):
./scripts/exec.sh ./scripts/casst-retrieval-eval.py \
  --fixtures profiles/acme/retrieval-eval.yaml
```

### 6. First query + SETUP_COMPLETE

```bash
./scripts/ask.sh "How do I deploy the product?" --product <source-id>
./scripts/setup-complete.sh   # doctor + REST/A2A smoke + FinClaw callers
# or: ./scripts/smoke-facade.sh <source-id>
```

The facade scopes the capability ledger with a **`products`** array. Prefer an
explicit source id (or rely on auto-scope when the pack has exactly one source).
Multi-source packs: pass `--product` for each relevant id.

First success = a JSON answer from `/v1/ask`. Grounding may return a short
*degraded* envelope if the model over-claims; that still proves the ledger path.
Capability pages under `runtime/answer-cache/wiki/capabilities/` improve answer
quality (see operator skills inside the image).

### 7. Operator console (see live traffic signals)

After a few asks, open the **operator console** in a browser:

```text
http://127.0.0.1:${CODE2WIKI_PORT:-8080}/operator
```

Example with a non-default port: `http://127.0.0.1:18080/operator`.

This is an **ops review UI** (not a chat window). It shows request counts,
gaps, FAQ drafts, and alias candidates so the appliance is not a black box.
Reads are open by default; **approve / reject / apply** need
`CASST_OPERATOR_TOKEN` set on the facade (Compose / `.env`), then paste the
same value into the console’s token field.

Populate the console from live asks (journal → report → snapshot):

```bash
# Inside the running image (default min cluster size is 2; use 1 while dogfooding)
./scripts/exec.sh sh -c 'EXPERIENCE_MIN_COUNT=1 ./scripts/run-experience-loop.sh all'
```

Then click **Reload snapshot** on `/operator`. Optional dissatisfaction signal:

```bash
curl -sS -X POST "http://127.0.0.1:${CODE2WIKI_PORT:-8080}/v1/feedback" \
  -H 'content-type: application/json' \
  -d '{"request_id":"<id-from-ask-or-journal>","verdict":"incomplete","detail":"…"}'
```

Journal path on the site: `runtime/logs/casst-journal.jsonl`.
`/healthz` → `operator.console` / `operator.snapshot_present` confirms the UI.

### 8. Optional callers

Site helpers (after SETUP_COMPLETE):

```bash
./scripts/ask-casst-a2a.sh "Your question"
./scripts/ask-casst-mcp.sh "Your question"
./scripts/run-setup-agent.sh   # FinClaw setup-guide profile
```

See [calling.md](calling.md) ([中文](calling.zh.md)) for protocol details.

## Common pitfalls

| Symptom | Likely cause |
|---------|----------------|
| `pull` / `up` cannot find image | Set `CODE2WIKI_IMAGE=code2wiki:dev` (or a GHCR tag) in `.env` |
| Port already allocated | Change `CODE2WIKI_PORT` (+ `CASST_PUBLIC_BASE_URL`) |
| Ask times out / empty body | Raise `CODE2WIKI_ASK_TIMEOUT`; check LLM key / provider in logs |
| Answers say ledger unknown / no capabilities | Run `./scripts/ingest.sh`; pass `--product <source-id>`; confirm `CASST_LEDGER_ROOT` |
| Retrieval eval 0% with `expect=[]` | Use `expect_sources:` in `retrieval-eval.yaml` |
| `[corpus-link] SKIP … no local/mirror` | Ingest/reconcile not run, or mirror path not linked (ingest.sh fixes this) |
| `/operator` empty (0 gaps / drafts) | Run experience loop after some asks; click **Reload snapshot** |
| Approve / apply returns 503 | Set `CASST_OPERATOR_TOKEN` in Compose / `.env` and restart; paste token in UI |
| `finclaw: command not found` | `./scripts/ensure-finclaw.sh` then `source runtime/.finclaw-env` or put `~/.local/bin` on PATH |
| get-started non-interactive fails | Pass `--repo id=url` (repeatable) or run on a TTY |
