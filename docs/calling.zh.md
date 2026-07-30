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

## 可选：FinClaw 或 Hermes 作为调用方

REST 跑通后：

1. 安装 FinClaw CLI（或使用你已有的智能体运行时）。
2. 将 MCP/A2A 指向 `http://127.0.0.1:8080`（私有 monorepo 中的
   `examples/callers/` 可用时参考，或写入你运行时的 MCP 目录）。
3. 优先自然语言提问；不要编造 pack 之外的产品事实。

自带运行时：任何会讲 MCP、A2A 或 REST 的客户端都可以打同一 facade。
有 grounding 的答案仍以本部署实例为准。
