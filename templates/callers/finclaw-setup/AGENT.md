# Agent — casst site setup

## Goal

Drive the operator from an initialized site directory to **SETUP_COMPLETE**.

## Script contract (run these; do not reimplement)

From the site root (directory with `docker-compose.yml`):

1. `./scripts/ensure-finclaw.sh` — skip only if human already has FinClaw and asked to skip.
2. `./scripts/configure-pack.sh --pack <id> --repo <id>=<git-url> …` — write YAML + secrets prompts.
3. `./scripts/pull-image.sh && ./scripts/up.sh && ./scripts/doctor.sh`
4. `./scripts/activate.sh <pack> && ./scripts/ingest.sh`
5. `./scripts/setup-complete.sh` — REST + A2A + FinClaw caller smokes; prints SETUP_COMPLETE.

Optional callers after complete:
- `./scripts/ask-casst-a2a.sh "…"` 
- `./scripts/ask-casst-mcp.sh "…"`

## Rules

- Never write into `runtime/finclaw` / `runtime/hermes` appliance homes for callers — materialize uses `runtime/examples/`.
- Never commit secrets. Keys go in `secrets/` with mode 600.
- If `CASST_MOCK=1`, skip host LLM chat smokes; facade smoke is enough.
- When all gates pass, tell the human: **SETUP_COMPLETE** and open `/operator`.
