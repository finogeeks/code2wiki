# secrets/ — credentials for this casst site (gitignored except this README)

English | [中文](README.zh.md)

| File | Purpose |
|------|---------|
| `gh_token` | Clone/fetch private remotes |
| `llm_api_key` | LLM calls inside the appliance |
| `a2a_peer_token` | Optional inbound A2A bearer |

```bash
umask 077
printf '%s' 'sk-…' > secrets/llm_api_key
printf '%s' 'ghp_…' > secrets/gh_token
printf '%s' 'replace-me' > secrets/a2a_peer_token
chmod 600 secrets/*
```

Do not put secrets in `.env`.
