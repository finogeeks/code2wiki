# AGENT — casst A2A caller (example)

Thin FinClaw host that peers with the code2wiki **casst** facade over A2A.

## Default workflow

1. Optional: `a2a_list_agents` if you need to confirm the `casst` peer exists.
2. **`a2a_send`** with `agent=casst` and the user’s question (or a clear
   rewrite of it).
3. Return casst’s answer (scrubbed by the facade) to the user in concise form.

## Do not

- Use `web_search`, `web_fetch`, or `http_request` for product knowledge.
- Read the local checkout hoping to answer suite questions when casst is up.
- Invent capabilities or cite unverified public pages when casst can answer.

## Failures

If `a2a_send` fails (auth, unreachable facade), report the error and stop.
Do not fall back to the open web for product facts.
