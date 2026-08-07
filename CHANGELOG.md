# Changelog

## [0.4.1] — 2026-08-06

- Warm miss path: default `CASST_WARM_CHAT_TIMEOUT_MS` **180s** (was 60s abort → cold).
  Dogfood `miss_warm` recheck: `transport=warm` 100% (`runtime/eval/latency-0.4.1-warm-timeout.json`).
- Facade tests: `FetchLike` / `ClawChildProcess` injectable types so tier0 typecheck passes.

## [0.4.0] — 2026-08-06

Ask **latency ladder**: FAQ/definition short-circuit + warm `finclaw serve` A2A
miss path with cold fallback; journal `ask_class` / `transport`; source-hint
header; `/healthz.claw`; `casst-latency-eval.py` gate.

### Latency Δ (dogfood appliance, §8)

| Cohort | Metric | 0.3 baseline (grounding off / cold miss) | 0.4 treatment |
|--------|--------|------------------------------------------|---------------|
| `faq_definition` | p50 / p95 | ~32s / ~85s (partial; no FAQ short-circuit) | **235ms / 238ms** (`transport=cache`) |
| `faq_definition` | gate p95 ≤ 5s | fail | **pass** |
| `miss_warm` | transport | n/a (pre-ladder) | warm works in smoke; long prompts still often `cold` fallback — follow-up |

Reports: `runtime/eval/latency-0.3.0.json`, `runtime/eval/latency-0.4.0.json`.
Operator how-to: `docs/testing/latency-eval.md`.

### Facade

- Supervise/adopt `finclaw serve`; warm chat via A2A `message/send` (secret bearer).
- `definition`/`faq` → `repairMax=0`; `X-Casst-Source-Hint`; `CASST_DEFAULT_USER`.

## [0.4.8] — 2026-08-08

Milestone on top of **0.4.7** linked filesystem sources. Structural /
artifact parity stays **flag-default-off** for FinDesk Knowledge Vault;
desktop argv, `/healthz.claw`, ask/warm/MCP shapes unchanged.


- Install: default FinClaw pin raised to **0.11.2** (`.env.example`,
  compose build arg, Dockerfile ARG, installer fallback). 0.10.4 ignores
  `loop_overrides.max_tool_calls`, and the stale `.env` pin silently
  downgraded rebuilds via compose interpolation.
- Latency: casst uses FinClaw `capability: coding`; set
  `AI_INFRA_RS_CODING_AGENT_LOOP_MAX_TOOL_CALLS=100` (research-sized for
  large corpora) and `AI_INFRA_RS_CODING_AGENT_LOOP_CONTINUATION_ENABLED=0`
  because profile `loop_overrides` are not yet written to `agent-loop.yaml`
  in FinClaw 0.11.2 (coding defaults otherwise enable a 120s continuation
  margin that emits checkpoint pauses on one-shot `/v1/ask`).
- Latency: aligned warm chat and FinClaw loop deadlines at 240s;
  timed-out warm requests no longer replay through cold chat.
- Latency: Graphify MCP registration is opt-in until its
  `Path.rglob(..., follow_symlinks=...)` startup failure is fixed; generated
  MCP calls default to 15s.
- Structural: flag-gated `CASST_STRUCTURAL_*` / `CASST_ARTIFACTS_*` layers,
  desktop-native adapter, additive `/healthz.structural` /
  `/healthz.artifacts` (never mutates `claw.status`).

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
