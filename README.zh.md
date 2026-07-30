# code2wiki（对外 intake）

[English](README.md) | 中文

**casst** 部署实例：基于*你的*产品 git 仓库回答问题。

本仓库是**客户接入面**：宿主机脚本、Compose 模板与文档。运行时是 **Docker 镜像**
（`ghcr.io/finogeeks/code2wiki`），无需从本仓库编译。

> 从私有 monorepo 发布到 GHCR + 本仓库仍属后续工作。
> 本地 dogfood：在私有仓库构建后设置 `CODE2WIKI_IMAGE=code2wiki:dev`。

## 快速开始

```bash
# 在本仓库（或 curl install.sh 之后）：
./scripts/init-site.sh ~/casst-site --pack acme
cd ~/casst-site

# 1) 编辑 pack 与 secrets
$EDITOR profiles/acme/sources.yaml
$EDITOR profiles/acme/retrieval-eval.yaml
printf '%s' 'your-llm-key' > secrets/llm_api_key
printf '%s' 'your-gh-pat'  > secrets/gh_token   # 私有远端需要时

# 2) 拉取镜像并启动 facade
./scripts/pull-image.sh
./scripts/up.sh

# 3) 激活 pack + REST 试问（不需要 FinClaw 调用方）
./scripts/activate.sh acme
./scripts/ask.sh "这个部署实例会回答哪些仓库的问题？"
```

引导式路径：`./scripts/get-started.sh ~/casst-site --pack acme`

## 会创建什么

| 路径 | 用途 |
|------|------|
| `profiles/<pack>/` | 你的 sources + retrieval-eval 脚手架 |
| `secrets/` | `llm_api_key`、`gh_token`、`a2a_peer_token`（权限 600） |
| `runtime/` | FinClaw/Hermes 主目录、答案缓存、日志、eval |
| `config/` | 已激活 pack 指针（由 `activate.sh` 写入） |
| `.env` | 非密钥配置 |
| `docker-compose.yml` | 用绑定挂载跑已发布镜像 |

## 首次成功 = REST

FinClaw / Hermes 作为*调用方*是可选的。见 [docs/calling.zh.md](docs/calling.zh.md)
（英文：[calling.md](docs/calling.md)）。

## 文档

- [docs/getting-started.zh.md](docs/getting-started.zh.md) · [English](docs/getting-started.md)
- [docs/calling.zh.md](docs/calling.zh.md) · [English](docs/calling.md)
