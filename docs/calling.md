# Calling the appliance

English | [中文](calling.zh.md)

Default success path is **REST** against the facade (no host agent required):

```bash
./scripts/ask.sh "Your question"
# or:
curl -sS http://127.0.0.1:8080/v1/ask \
  -H 'content-type: application/json' \
  -d '{"question":"Your question"}'
```

Also available: `POST /v1/explain`, `POST /v1/generate`, `GET /healthz`,
`GET /operator` (set `CASST_OPERATOR_TOKEN` for publish actions).

## Facade surfaces (same appliance)

Base URL is `http://127.0.0.1:8080` by default (or your reverse proxy).

| Surface | Endpoint | Auth | Notes |
|---------|----------|------|-------|
| REST ask | `POST /v1/ask` | none (put the appliance behind your gateway if exposed) | Also `/v1/explain`, `/v1/generate` |
| MCP | `POST /mcp` | none (same) | Streamable HTTP; tools `ask`, `explain`, `generate` |
| A2A card | `GET /.well-known/agent-card.json` | none | Discovery for A2A peers |
| A2A RPC | `POST /a2a/v1` | `Authorization: Bearer <token>` | JSON-RPC; token from site `secrets/a2a_peer_token` |

Prefer natural-language asks. Do not invent product facts outside the activated
pack—the appliance is the grounded source of truth.

## Optional: FinClaw, Hermes, or any caller agent

After REST works, point *your* agent runtime at the facade:

1. Install FinClaw, Hermes, or another runtime you already use.
2. Register the appliance as an MCP server (`…/mcp`) and/or an A2A peer
   (`…/a2a/v1` + bearer from `secrets/a2a_peer_token`).
3. Teach the caller to **delegate** (“ask casst”) instead of answering from
   its own memory.

Bring-your-own runtime: any client that speaks MCP, A2A, or REST can call the
same facade. Caller config lives in *your* runtime’s homes and catalogs—not in
this intake repository.
