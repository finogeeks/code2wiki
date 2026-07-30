# Example: FinClaw → casst over A2A

**Not production software.** Copy these templates into your own agent runtime,
or materialize for a one-off smoke against a local appliance.

## Prerequisites

- Appliance up: `curl -fsS http://127.0.0.1:8080/healthz`
- `secrets/a2a_peer_token` (or `CASST_A2A_PEER_TOKEN`)
- Host `finclaw` on PATH + `LLM_API_KEY` for chat

## Smoke

```bash
./scripts/materialize-example-caller.sh finclaw-a2a
export CASST_A2A_PEER_TOKEN="$(tr -d '\r\n' < secrets/a2a_peer_token)"
FINCLAW_HOME=runtime/examples/finclaw-a2a finclaw a2a probe --profile casst-caller casst
# Natural question — expect a2a_send (web_search/web_fetch denied in this example)
FINCLAW_HOME=runtime/examples/finclaw-a2a finclaw chat --profile casst-caller \
  -m 'What is casst? Keep it short.'
# or: ./scripts/ask-casst-a2a.sh "What is casst?"
```

This pack installs `IDENTITY.md` / `AGENT.md` / `TOOLS.md` plus a
`tool-invocation-policy.yaml` that denies open-web tools so the host agent
defaults to `a2a_send` → `casst`. Rematerialize after editing those files;
start a **new** chat session so policy reloads.

You do not need to invent REST `products[]` on A2A: the facade auto-scopes
when the appliance has a single registered source, or accepts
`Product: <id>` prose / A2A metadata when several sources are registered.

See [calling-the-appliance](../../../docs/calling-the-appliance.md).
