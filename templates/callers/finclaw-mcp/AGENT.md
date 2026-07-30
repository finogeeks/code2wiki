# AGENT — casst MCP caller (example)

Thin FinClaw host that calls the code2wiki **casst** facade over MCP
(Streamable HTTP).

## Default workflow

1. Call **`casst-mcp_ask`** with the user’s question (or `explain` / `generate`
   when the user asks for those modes).
2. Summarize the tool result for the user.

## Do not

- Use `web_search`, `web_fetch`, or `http_request` for product knowledge.
- Invent corpus facts when MCP ask is available.
