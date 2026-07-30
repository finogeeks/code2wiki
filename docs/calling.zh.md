# 调用部署实例

[English](calling.md) | 中文

默认成功路径是对 facade 的 **REST**（宿主机无需安装智能体）：

```bash
./scripts/ask.sh "你的问题" --product <source-id>
# 或：
curl -sS http://127.0.0.1:8080/v1/ask \
  -H 'content-type: application/json' \
  -d '{"question":"你的问题","products":["<source-id>"]}'
```

`products` 用于限定能力账本范围（可诚实回答 yes/no/planned）。单 source 的 pack：
省略 `--product` 时 `ask.sh` 会自动带上唯一 id。
另有：`POST /v1/explain`、`POST /v1/generate`、`GET /healthz`。
运营审阅界面：**`GET /operator`**（见下）。

## Facade 接口（同一部署实例）

默认基址 `http://127.0.0.1:8080`（或你的反向代理）。

| 接口 | 端点 | 鉴权 | 说明 |
|------|------|------|------|
| REST 提问 | `POST /v1/ask` | 无（对外暴露时请放在网关后） | 另有 `/v1/explain`、`/v1/generate` |
| 运营控制台 | `GET /operator` | 默认可读；写操作需 Bearer | gaps、FAQ 草稿、别名候选 — 不是聊天窗 |
| 运营快照 | `GET /v1/operator/snapshot` | 同控制台 | 控制台使用的 JSON |
| 反馈 | `POST /v1/feedback` | 无（同 REST） | `{ request_id, verdict: wrong\|incomplete\|good }` |
| MCP | `POST /mcp` | 无（同上） | Streamable HTTP；工具 `ask`、`explain`、`generate` |
| A2A 名片 | `GET /.well-known/agent-card.json` | 无 | 供 A2A 对等体发现 |
| A2A RPC | `POST /a2a/v1` | `Authorization: Bearer <token>` | JSON-RPC；令牌来自站点 `secrets/a2a_peer_token` |

### 运营控制台

facade 启动后在浏览器打开：

```text
http://127.0.0.1:${CODE2WIKI_PORT:-8080}/operator
```

用途：对线上提问做**人工审阅**（journal → experience loop → 快照），不是终端用户聊天。填充方式：

```bash
./scripts/exec.sh sh -c 'EXPERIENCE_MIN_COUNT=1 ./scripts/run-experience-loop.sh all'
```

然后点 **Reload snapshot**。批准 / 拒绝 / 应用前在 Compose / `.env` 设置
`CASST_OPERATOR_TOKEN`，并在控制台粘贴同一令牌。完整步骤：
[getting-started.zh.md](getting-started.zh.md#7-运营控制台查看线上提问信号)。

优先自然语言提问。不要编造已激活 pack 之外的产品事实——有依据的答案以本部署实例为准。

## 可选：FinClaw、Hermes 或任意调用方智能体

REST 跑通后（或跑完 `./scripts/setup-complete.sh`），把*你的*智能体运行时指向 facade。

### 站点助手（FinClaw）

模板在 `templates/callers/`，物化到 `runtime/examples/`（不要写进实例
`runtime/finclaw` / `runtime/hermes`）：

```bash
./scripts/ensure-finclaw.sh
./scripts/materialize-caller.sh finclaw-a2a
./scripts/materialize-caller.sh finclaw-mcp
./scripts/ask-casst-a2a.sh "你的问题"
./scripts/ask-casst-mcp.sh "你的问题"
```

`setup-complete.sh` 会自动 materialize + `finclaw a2a probe` +
`finclaw mcp outbound-test`。

### 自带运行时

1. 安装 FinClaw、Hermes，或使用你已有的运行时。
2. 将本部署实例登记为 MCP 服务（`…/mcp`）和/或 A2A 对等体
   （`…/a2a/v1` + 来自 `secrets/a2a_peer_token` 的 Bearer）。
3. 让调用方**委托**（「去问 casst」），而不是用自己的记忆编造答案。

任何会讲 MCP、A2A 或 REST 的客户端都可以打同一 facade。调用方配置写在*你自己的*
运行时主目录里——不在镜像内。
