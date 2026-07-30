# Example: FinClaw → casst over MCP

**Not production software.** Adapt this catalog to your runtime’s MCP config.

## Smoke

```bash
./scripts/materialize-example-caller.sh finclaw-mcp
FINCLAW_HOME=runtime/examples/finclaw-mcp \
  AI_INFRA_RS_HOME=runtime/examples/finclaw-mcp/profiles/casst-caller/runtime_home \
  finclaw mcp outbound-test casst-mcp --timeout 20
# Natural question — expect casst-mcp_ask (web tools denied)
FINCLAW_HOME=runtime/examples/finclaw-mcp finclaw chat --profile casst-caller \
  -m 'What surfaces does the casst facade expose? Keep it short.'
```

Pack installs `IDENTITY.md` / `AGENT.md` / `TOOLS.md` plus a deny list for
`web_search` / `web_fetch` / `http_request`. Rematerialize after edits; new chat.

See [calling-the-appliance](../../../docs/calling-the-appliance.md).
