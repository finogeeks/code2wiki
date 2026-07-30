# 入门指南

[English](getting-started.md) | 中文

## 前置条件

- Docker + Compose v2
- LLM API Key（真实回答需要；管道冒烟可用 `CASST_MOCK=1`）
- 你有权克隆的 Git 远端（公开 HTTPS，或在 `secrets/gh_token` 中放 PAT）

## 步骤

### 1. 创建 site 目录

```bash
./scripts/init-site.sh ~/casst-site --pack acme
cd ~/casst-site
```

### 2. 配置 pack

编辑 `profiles/acme/sources.yaml` —— 把示例远端换成你的仓库。
除非语料本意公开，否则保持 `visibility: private`。

在 `profiles/acme/retrieval-eval.yaml` 中写入 5–15 个真实问题。

### 3. Secrets

```bash
printf '%s' 'sk-…' > secrets/llm_api_key
printf '%s' 'ghp_…' > secrets/gh_token   # 需要时
chmod 600 secrets/*
```

可选：在 `.env` 中设置 `LLM_PROVIDER` / `LLM_MODEL`。

### 4. 镜像 + 启动

```bash
./scripts/pull-image.sh          # 使用 CODE2WIKI_IMAGE / VERSION
./scripts/up.sh                  # facade 默认 :8080
./scripts/doctor.sh              # /healthz
```

对着私有构建的镜像做本地 dogfood：

```bash
export CODE2WIKI_IMAGE=code2wiki:dev
./scripts/up.sh
```

### 5. 激活 + 评测（在部署实例内）

```bash
./scripts/activate.sh acme
# 可选路由门禁（需填好 retrieval-eval）：
./scripts/exec.sh ./scripts/casst-retrieval-eval.py
```

### 6. 首次提问（REST —— 必选路径）

```bash
./scripts/ask.sh "生产环境怎么部署这个产品？"
```

### 7. 可选调用方

REST 跑通后，FinClaw A2A/MCP 或 Hermes 见 [calling.zh.md](calling.zh.md)。
