# Changelog

## [unreleased]

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
