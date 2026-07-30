# 调用部署实例

[English](calling.md) | 中文

默认成功路径是对 facade 的 **REST**（宿主机无需安装智能体）：

```bash
./scripts/ask.sh "你的问题"
# 或：
curl -sS http://127.0.0.1:8080/v1/ask \
  -H 'content-type: application/json' \
  -d '{"question":"你的问题"}'
```

另有：`POST /v1/explain`、`POST /v1/generate`、`GET /healthz`、
`GET /operator`（发布操作需设置 `CASST_OPERATOR_TOKEN`）。

## Facade 接口（同一部署实例）

默认基址 `http://127.0.0.1:8080`（或你的反向代理）。

| 接口 | 端点 | 鉴权 | 说明 |
|------|------|------|------|
| REST 提问 | `POST /v1/ask` | 无（对外暴露时请放在网关后） | 另有 `/v1/explain`、`/v1/generate` |
| MCP | `POST /mcp` | 无（同上） | Streamable HTTP；工具 `ask`、`explain`、`generate` |
| A2A 名片 | `GET /.well-known/agent-card.json` | 无 | 供 A2A 对等体发现 |
| A2A RPC | `POST /a2a/v1` | `Authorization: Bearer <token>` | JSON-RPC；令牌来自站点 `secrets/a2a_peer_token` |

优先自然语言提问。不要编造已激活 pack 之外的产品事实——有依据的答案以本部署实例为准。

## 可选：FinClaw、Hermes 或任意调用方智能体

REST 跑通后，把*你的*智能体运行时指向 facade：

1. 安装 FinClaw、Hermes，或使用你已有的运行时。
2. 将本部署实例登记为 MCP 服务（`…/mcp`）和/或 A2A 对等体
   （`…/a2a/v1` + 来自 `secrets/a2a_peer_token` 的 Bearer）。
3. 让调用方**委托**（「去问 casst」），而不是用自己的记忆编造答案。

自带运行时：任何会讲 MCP、A2A 或 REST 的客户端都可以打同一 facade。
调用方配置写在*你自己的*运行时主目录 / 目录里——不在本接入仓库中。
