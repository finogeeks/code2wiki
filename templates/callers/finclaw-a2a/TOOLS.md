# TOOLS — casst A2A caller (example)

## Prefer

| Tool | When |
|------|------|
| `a2a_send` | **Default** for product / suite / architecture questions (`agent=casst`) |
| `a2a_list_agents` / `a2a_probe` | Debugging peer wiring |

## Avoid for knowledge answers

| Tool | Why |
|------|-----|
| `web_search` | Bypasses casst; often wrong or public-only |
| `web_fetch` | Same |
| `http_request` | Same |

This example profile **denies** `web_search`, `web_fetch`, and `http_request`
via `policies/tool-invocation-policy.yaml` so the model cannot quietly skip
A2A. Re-run `./scripts/materialize-example-caller.sh finclaw-a2a` after editing
that file, then start a new chat session.
