# 入门指南

[English](getting-started.md) | 中文

## 前置条件

- Docker + Compose v2
- LLM API Key（真实回答需要；管道冒烟可用 `CASST_MOCK=1`）
- 你有权克隆的 Git 远端（公开 HTTPS，或在 `secrets/gh_token` 中放 PAT）
- code2wiki 镜像：已发布的 `ghcr.io/finogeeks/code2wiki:<ver>`，**或**本机 dogfood
  标签如 `code2wiki:dev`（在 `.env` 里设 `CODE2WIKI_IMAGE`）
- 可选：宿主机 [FinClaw CLI](https://github.com/finogeeks/finclaw-cli)（A2A/MCP
  冒烟；`./scripts/ensure-finclaw.sh` 可安装）

## 引导路径（推荐）

**无需克隆、无需抄参数** — 在终端执行；安装器会询问站点、pack、远端：

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/code2wiki/main/install.sh | sh
```

若已有接入仓库检出（默认也是交互式）：

```bash
./scripts/get-started.sh
```

CI / 非交互（参数全部显式给出）：

```bash
./scripts/get-started.sh --site ~/casst-site --pack acme \
  --repo my-app=https://github.com/org/app.git
```

常用标志：`--lang zh|en`、`--mock`、`--skip-finclaw`、`--skip-caller`、`--agent`
（完成后进入 FinClaw 设置对话）、`--force`、`--no-up`（配置完即停）。语言也可由
`CODE2WIKI_LANG` 或 `LANG`（`zh*` → 中文）决定。

成功标志：出现 `SETUP_COMPLETE` 横幅，且存在
`runtime/eval/SETUP_COMPLETE.json`。然后可跳到
[§7 运营控制台](#7-运营控制台查看线上提问信号)。

## 手动步骤

### 1. 创建 site 目录

```bash
./scripts/init-site.sh ~/casst-site --pack acme
cd ~/casst-site
```

若本机 `:8080` 已被占用，编辑 `.env`：

```bash
CODE2WIKI_PORT=18080
CASST_PUBLIC_BASE_URL=http://127.0.0.1:18080
# 同一 Docker 上跑多个站点时可选：
# COMPOSE_PROJECT_NAME=casst-acme
```

### 2. 配置 pack

优先用助手（写 YAML + 可选 secrets）：

```bash
./scripts/configure-pack.sh --pack acme \
  --repo my-app=https://github.com/org/app.git
# 交互式 TTY 可不传 --repo
```

或手改 `profiles/acme/sources.yaml`。除非语料本意公开，否则保持
`visibility: private`。`retrieval-eval.yaml` 用
`expect_sources: [你的-source-id]`（不要用 `expect_source_ids`）。

### 3. Secrets

```bash
printf '%s' 'sk-…' > secrets/llm_api_key
printf '%s' 'ghp-…' > secrets/gh_token   # 需要时
chmod 600 secrets/*
```

`configure-pack` 在 `a2a_peer_token` 为空时可自动生成。可选：在 `.env` 设置
`LLM_PROVIDER` / `LLM_MODEL` / `LLM_BASE_URL`。

### 4. 镜像 + 启动

```bash
# 本地 dogfood（GHCR 发布仍属后续工作）：
# echo 'CODE2WIKI_IMAGE=code2wiki:dev' >> .env

./scripts/pull-image.sh
./scripts/up.sh
./scripts/doctor.sh
```

### 5. 激活 + 摄取（要有据回答，这一步必做）

```bash
./scripts/activate.sh acme
./scripts/ingest.sh
# 或：./scripts/ingest.sh --source <id>

# 可选路由门禁：
./scripts/exec.sh ./scripts/casst-retrieval-eval.py \
  --fixtures profiles/acme/retrieval-eval.yaml
```

### 6. 首次提问 + SETUP_COMPLETE

```bash
./scripts/ask.sh "生产环境怎么部署这个产品？" --product <source-id>
./scripts/setup-complete.sh   # doctor + REST/A2A + FinClaw 调用方
# 或：./scripts/smoke-facade.sh <source-id>
```

facade 用 **`products`** 限定能力账本。优先显式传 source id；单 source pack
可自动带上。首次成功 = `/v1/ask` 返回 JSON。

### 7. 运营控制台（查看线上提问信号）

```text
http://127.0.0.1:${CODE2WIKI_PORT:-8080}/operator
```

这是**运营审阅界面**（不是聊天窗）。默认可读；**批准 / 拒绝 / 应用** 需要
`CASST_OPERATOR_TOKEN`，并在控制台粘贴同一值。

```bash
./scripts/exec.sh sh -c 'EXPERIENCE_MIN_COUNT=1 ./scripts/run-experience-loop.sh all'
```

然后 **Reload snapshot**。可选反馈：`POST /v1/feedback`。
站点日志：`runtime/logs/casst-journal.jsonl`。

### 8. 可选调用方

```bash
./scripts/ask-casst-a2a.sh "你的问题"
./scripts/ask-casst-mcp.sh "你的问题"
./scripts/run-setup-agent.sh
```

协议细节见 [calling.zh.md](calling.zh.md)。

## 常见坑

| 现象 | 常见原因 |
|------|----------|
| pull/up 找不到镜像 | `.env` 设置 `CODE2WIKI_IMAGE=code2wiki:dev`（或 GHCR 标签） |
| 端口已被占用 | 改 `CODE2WIKI_PORT`（并改 `CASST_PUBLIC_BASE_URL`） |
| ask 超时 / 空响应 | 提高 `CODE2WIKI_ASK_TIMEOUT`；查 LLM 密钥与日志 |
| 回答称 ledger unknown / 无 capabilities | 先跑 `./scripts/ingest.sh`；传 `--product`；确认 `CASST_LEDGER_ROOT` |
| 检索评测 0% 且 `expect=[]` | `retrieval-eval.yaml` 使用 `expect_sources:` |
| `[corpus-link] SKIP … no local/mirror` | 未 ingest，或镜像路径未链接（`ingest.sh` 会处理） |
| `/operator` 为空（0 gaps / drafts） | 有提问后跑 experience loop，再点 **Reload snapshot** |
| 批准 / 应用返回 503 | 在 Compose / `.env` 设置 `CASST_OPERATOR_TOKEN` 并重启；控制台粘贴同一令牌 |
| `finclaw: command not found` | 跑 `./scripts/ensure-finclaw.sh`，再 `source runtime/.finclaw-env` 或把 `~/.local/bin` 加入 PATH |
| get-started 非交互失败 | 传 `--repo id=url`（可重复），或在 TTY 下运行 |
