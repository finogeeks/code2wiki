# Calling the appliance

English | [中文](calling.zh.md)

Default success path is **REST** against the facade (no host agent required):

```bash
./scripts/ask.sh "Your question" --product <source-id>
# or:
curl -sS http://127.0.0.1:8080/v1/ask \
  -H 'content-type: application/json' \
  -d '{"question":"Your question","products":["<source-id>"]}'
```

`products` scopes the capability ledger (honest yes/no/planned). Single-source
packs: `ask.sh` auto-adds the only source id when `--product` is omitted.
The facade applies the same auto-scope on **MCP and A2A** when `products` is
omitted and exactly one source is registered; multi-source packs still need an
explicit id (`products[]`, A2A metadata, or prose `Product: <id>`).
Also available: `POST /v1/explain`, `POST /v1/generate`, `GET /healthz`.
Operator review UI: **`GET /operator`** (see below).

## Facade surfaces (same appliance)

Base URL is `http://127.0.0.1:8080` by default (or your reverse proxy).

| Surface | Endpoint | Auth | Notes |
|---------|----------|------|-------|
| REST ask | `POST /v1/ask` | none (put the appliance behind your gateway if exposed) | Also `/v1/explain`, `/v1/generate` |
| Operator console | `GET /operator` | reads open by default; writes need Bearer | Gaps, FAQ drafts, alias candidates — not a chat UI |
| Operator snapshot | `GET /v1/operator/snapshot` | same as console | JSON used by the console |
| Feedback | `POST /v1/feedback` | none (same as REST) | `{ request_id, verdict: wrong\|incomplete\|good }` |
| MCP | `POST /mcp` | none (same) | Streamable HTTP; tools `ask`, `explain`, `generate` |
| A2A card | `GET /.well-known/agent-card.json` | none | Discovery for A2A peers |
| A2A RPC | `POST /a2a/v1` | `Authorization: Bearer <token>` | JSON-RPC; token from site `secrets/a2a_peer_token` |

### Operator console

Open in a browser after the facade is up:

```text
http://127.0.0.1:${CODE2WIKI_PORT:-8080}/operator
```

Purpose: **human-in-the-loop** review of live ask traffic (journal → experience
loop → snapshot), not end-user chat. Populate it with:

```bash
./scripts/exec.sh sh -c 'EXPERIENCE_MIN_COUNT=1 ./scripts/run-experience-loop.sh all'
```

Then **Reload snapshot**. Set `CASST_OPERATOR_TOKEN` in Compose / `.env` before
approve / reject / apply (paste the same token in the console). Full walkthrough:
[getting-started.md](getting-started.md#7-operator-console-see-live-traffic-signals).

Prefer natural-language asks. Do not invent product facts outside the activated
pack—the appliance is the grounded source of truth.

## Optional: FinClaw, Hermes, or any caller agent

After REST works (or after `./scripts/setup-complete.sh`), point *your* agent
runtime at the facade.

### Site helpers (FinClaw)

Templates live under `templates/callers/` and materialize into
`runtime/examples/` (never into appliance `runtime/finclaw` / `runtime/hermes`):

```bash
./scripts/ensure-finclaw.sh
./scripts/materialize-caller.sh finclaw-a2a
./scripts/materialize-caller.sh finclaw-mcp
./scripts/ask-casst-a2a.sh "Your question"
./scripts/ask-casst-mcp.sh "Your question"
```

`setup-complete.sh` runs materialize + `finclaw a2a probe` +
`finclaw mcp outbound-test` automatically.

### Bring-your-own runtime

1. Install FinClaw, Hermes, or another runtime you already use.
2. Register the appliance as an MCP server (`…/mcp`) and/or an A2A peer
   (`…/a2a/v1` + bearer from `secrets/a2a_peer_token`).
3. Teach the caller to **delegate** (“ask casst”) instead of answering from
   its own memory.

Any client that speaks MCP, A2A, or REST can call the same facade. Caller
config lives in *your* runtime’s homes—not inside the appliance image.
