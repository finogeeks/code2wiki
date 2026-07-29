# Calling the appliance

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

## Optional: FinClaw or Hermes as callers

After REST works:

1. Install FinClaw CLI (or use your existing agent runtime).
2. Point MCP/A2A at `http://127.0.0.1:8080` (see private monorepo
   `examples/callers/` when available, or your runtime’s MCP catalog).
3. Prefer natural-language asks; do not invent product facts outside the pack.

Bring-your-own runtime: any client that speaks MCP, A2A, or REST can call the
same facade. The appliance stays the source of grounded answers.
