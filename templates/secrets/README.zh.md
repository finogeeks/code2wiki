# secrets/ — 本 casst site 的凭证（除本 README 外均 gitignore）

[English](README.md) | 中文

| 文件 | 用途 |
|------|------|
| `gh_token` | 克隆/拉取私有远端 |
| `llm_api_key` | 部署实例内的 LLM 调用 |
| `a2a_peer_token` | 可选：入站 A2A Bearer |

```bash
umask 077
printf '%s' 'sk-…' > secrets/llm_api_key
printf '%s' 'ghp_…' > secrets/gh_token
printf '%s' 'replace-me' > secrets/a2a_peer_token
chmod 600 secrets/*
```

不要把密钥写进 `.env`。非密钥的 LLM 路由（`LLM_PROVIDER`、`LLM_BASE_URL`、
`LLM_MODEL`）写在 `.env`（可由 `configure-pack` 写入）。
