# Changelog

## [unreleased]

- Install: on macOS, offer **Apple Container** (`container`) alongside Docker
  engines when installed; `up`/`down`/`exec`/`pull`/`activate`/`ingest` work via
  `CODE2WIKI_RUNTIME=apple` (secrets injected as env; `container system start`
  on demand). Pick with the engine prompt, `--runtime apple`, or
  `--docker-context apple`.
- Install: detect Docker engines early — abort with install hints if none;
  if several reachable contexts (Desktop / OrbStack / Colima / …), prompt to
  pick one (or `--docker-context` / `DOCKER_CONTEXT`); pin choice in site `.env`.
- Install: `pull-image` refreshes registry tags by default (`docker pull` so
  republished `:latest` / same tag updates apply); set `CODE2WIKI_PULL=0` for
  airgap. Local tags like `code2wiki:dev` still skip pull unless forced.
- Install: `configure-pack` prompts for full LLM config (provider, base URL,
  model, API key) and writes `LLM_*` into `.env` — no OpenAI default assumed;
  flags `--llm-provider` / `--llm-base-url` / `--llm-model` / `--llm-key-file`
  for CI. `templates/env.example` leaves `LLM_*` empty.
- Install UX: zh/en i18n via `CODE2WIKI_LANG` / `LANG` (or `--lang`), message
  catalogs under `scripts/lib/i18n/`, numbered step banners, and a healthz
  wait spinner — still pure shell (no Node).
- Install: harden `~/` site-path expansion for macOS/Linux/Windows (Git Bash):
  trim whitespace/quotes, accept `~/…` and `~\…`, `$HOME/…`, resolve
  `HOME`/`USERPROFILE`, expand in both `get-started` and `init-site`, and refuse
  to create a literal `~` directory.
- Install: always refresh the XDG intake cache (`~/.local/share/code2wiki-intake`)
  to `origin/main` on `curl|sh` (previously skipped update when the cache already
  existed, so tilde-path and smoke fixes never applied).
- Install: expand `~/…` site paths correctly (bash was tilde-expanding the
  `${p#~/}` pattern, creating `$HOME/~/…` directories); smoke prints HTTP error
  bodies so LLM/transport failures are visible instead of bare `HTTP 400`.
- Install: default `curl …/install.sh | sh` is interactive (site / pack /
  remotes / secrets via `/dev/tty`, so it works when stdin is the script);
  flags remain for CI. README Quick start no longer hard-codes example paths.
- Docs: lead Quick start with a oneshot
  `curl …/install.sh | sh` (EN/ZH README + getting-started); checkout/
  `get-started` remains the secondary path.
- Guided onboarding: `install.sh` / `get-started.sh` orchestrate init →
  FinClaw (`ensure-finclaw.sh`) → `configure-pack.sh` → up → activate →
  ingest → `setup-complete.sh` (REST + A2A + FinClaw A2A/MCP) with
  `SETUP_COMPLETE` badge; public caller templates under `templates/callers/`;
  helpers `materialize-caller`, `smoke-facade`, `ask-casst-{a2a,mcp}`,
  `run-setup-agent`. Compose isolation (`COMPOSE_PROJECT_NAME=casst-<pack>`),
  free-port pick, and site-local base URL (ignore parent-shell `CASST_*`).
- Reconcile: honor `default_branch` (and pack YAML emits both `default_branch`
  + `branch`) so non-`main` remotes clone correctly.
- Docs: document operator console access (`GET /operator`), experience-loop
  populate steps, feedback, and token pitfalls in public getting-started /
  calling / README (EN/ZH).
- Facade ask scope: REST/MCP/A2A resolve products via explicit ids, validated
  `Product:` / `products:` prose, or single-source auto-scope — so A2A callers
  match `./scripts/ask.sh --product` on one-source packs without inventing
  REST `products[]`.
- Path alignment: ledger/FAQ/corrections follow `ANSWER_CACHE` /
  `CASST_LEDGER_ROOT` (facade, Python CLIs, doctor, entrypoint, ready-to-serve,
  apply-seed). Corpus-link resolves `CODE2WIKI_DATA/mirrors` before the legacy
  workspace path.
- Day-1 ledger: `scripts/bootstrap-capability-stubs.py` + `scripts/ingest.sh`
  seed a README overview page when a product has no capabilities yet; public
  `ingest.sh` calls it when the image includes the helper.
- Operator dogfood fixes: add `scripts/ingest.sh` (reconcile + corpus-link);
  pin `CASST_LEDGER_ROOT` in Compose; fix pack template `expect_sources`;
  `ask.sh` sends `products[]` (and auto-scopes single-source packs).
- Docs: quick start / getting-started include ingest, port conflicts, dogfood
  image, and a pitfalls table (EN/ZH).
- Keep public docs self-contained: no private-repo path pointers; document
  facade MCP/A2A surfaces inline in `docs/calling*.md`.
- Restructure README (EN/ZH): plain-language product intro, operator vs caller,
  high-level architecture / working theory, then operator quick start.
- Add Chinese docs: `README.zh.md`, `docs/getting-started.zh.md`, `docs/calling.zh.md`.
- Initial public intake: `init-site`, `pull-image`, `up`, `activate`, `ask`, `get-started`.
