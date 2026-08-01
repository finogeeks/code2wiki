# code2wiki

[English](README.md) | 中文

运行一套**知识部署实例（appliance）**：基于*你的*产品 Git 仓库回答问题，并让人或其他 AI 智能体通过网络来调用它。

本仓库是**客户接入面**：宿主机脚本、Compose 模板与文档。系统的主体以 **Docker 镜像**
（`ghcr.io/finogeeks/code2wiki`）交付，无需从本仓库编译。

> **镜像：** 优先使用已发布标签，例如
> `CODE2WIKI_IMAGE=ghcr.io/finogeeks/code2wiki:0.1.0`（见本仓库 `VERSION`）。
> 本地 dogfood 可构建或载入本机标签，如 `code2wiki:dev`。

---

## 这是什么？

多数公司真正的产品真相已经在 Git 里：代码、设计说明、规范、路线图。但这份真相很少以可信的形式到达销售、交付、售前、市场或高管。百科和 PPT 会过期，专家会成为瓶颈。

**code2wiki** 把你选定的 Git 远端变成活的知识底座，并养出一个可问的产品「**智能体分身**」。我们把这个分身叫 **casst**（**C**ode **A**s **S**ingle **S**ource of **T**ruth）：

- 把它指到定义*你的*产品的那些仓库；
- 用人话提问（或让另一个智能体代你问）；
- 得到锚定在这些仓库上的答案——而不是上季度某份宣传册里的说法。

它**不是**「把 PDF 丢进又一个 ChatGPT」。被管理的产品真相，就是你配置的 Git。换远端，知识出口跟着变。

---

## 两边各干什么

可以想成一家店：一边是店面运营，一边是进店的客人。

| 一侧 | 是谁 | 要做什么 |
|------|------|----------|
| **运营方（Operator）** | 你（平台 / 运维 / 知识负责人） | 选定哪些仓库算真相、部署实例、保管密钥、激活 pack、巡检健康 |
| **调用方（Caller）** | 人、脚本，或另一个 AI 智能体 | 提问并消费答案——今天用 REST；之后可用 MCP / A2A，从 FinClaw、Hermes、IDE 助手等发起 |

**本接入仓库服务的是运营方。** 帮你在宿主机上建站点目录、拉镜像、起容器，并用一次简单的 HTTP 提问证明 facade 可用。

**调用方智能体是可选的、且分开的。** facade 起来之后，任何会说已发布协议的客户端都能调用。宿主机上**不需要**装 FinClaw 或 Hermes 也能拿到第一次成功答案——REST 就够。Agent 运行时是*appliance 的客户*，不是 appliance 本身的一部分。

```text
  运营方（本仓库 + 你的主机）                    调用方（别处）
  ─────────────────────────                    ────────────
  profiles / secrets / compose                 人（curl、ask.sh）
        │                                      对等 Agent（MCP / A2A）
        ▼                                      IDE / 工具链助手
  Docker 镜像  ──facade :8080──►  答案  ◄──── 任意 REST/MCP/A2A 客户端
  （casst + 策展 + 运行时）
```

---

## 怎么工作（工作原理）

1. **你声明知识源。** 在 `profiles/<name>/` 下的 *pack* 里列出作为产品真相的 Git 远端（以及 eval 脚手架）。pack 就是运营契约：「这些仓库是真相。」
2. **你启动部署实例。** Compose 跑已发布镜像，并把站点目录绑定挂载进去（`profiles/`、`secrets/`、`runtime/`、`config/`）。容器内由常驻的智能体运行时（FinClaw / `serve`）托管 casst 人设，以及对外说话的 **facade**（HTTP，以及 MCP / A2A）。
3. **facade 是唯一大门。** 调用方不会直接摸到你的 Git 克隆或 LLM 密钥。他们只访问 `http://<主机>:8080`（或你的反向代理）。appliance 按配置检索知识，用你的 LLM 密钥推理，返回有依据的答案。
4. **暖服务，不是一次性聊天。** 很多人、很多智能体可能同时来问。运行时按共享在线服务来设计（多用户、并发请求、冷启动只付一次）——而不是每个问题都重新拉起的个人助手进程。
5. **调用方对产品事实保持「无知」。** 调用侧的 FinClaw / Hermes 智能体应当*委托*（「去问 casst」），而不是自己编造功能。锚定留在 appliance 内。

一句话：

> 运营方跑真相服务；调用方只负责问。真相来源 = Git。大门 = facade。脑子 = 镜像里的 casst。

---

## 为什么值得做（简述）

在数字化程度够高的组织里，**代码日益成为业务本身**。销售、交付、售前、市场、研发——以及各岗位旁边的智能体——本该对齐同一套产品事实。code2wiki 让这套事实变得*可问*，而不是再写一套渐渐过时的百科。

分身「能用」之后，真正的门槛往往是**运行时形态**（冷启动、并发调用），而不只是模型聪不聪明。所以镜像选用面向服务的 Agent Runtime，而不是单用户聊天 App。

---

## 快速开始（运营方路径）

**一键安装** — 无需先克隆，也无需抄示例参数。在终端执行后，安装器会询问
站点目录、pack 名称、Git 远端，以及完整 LLM 配置（提供方、base URL、模型、API
密钥 — 不默认 openai）：

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/code2wiki/main/install.sh | sh
```

会拉取/更新接入面，再引导 configure → up → activate → ingest → REST/A2A/FinClaw
冒烟，并写入 `<站点>/runtime/eval/SETUP_COMPLETE.json`。提示语言跟随 `LANG` /
`CODE2WIKI_LANG=zh|en`（或 `get-started --lang`）。

仅 CI / 自动化时需要带标志：

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/code2wiki/main/install.sh | sh -s -- \
  --site ~/casst-site --pack acme \
  --repo my-app=https://github.com/org/app.git
```

前置：容器引擎 — Docker + Compose v2（Desktop / OrbStack / Colima）和/或 macOS
上的 Apple Container；没有则中止，多个可用会提示选择。以及能访问你的 Git 远端。

默认 `./scripts/pull-image.sh` 使用 `ghcr.io/finogeeks/code2wiki` 与 `VERSION` 钉。
仅本地 dogfood 时：

```bash
echo 'CODE2WIKI_IMAGE=code2wiki:dev' >> ~/casst-site/.env   # 换成你的站点路径
```

**已经克隆本仓库？** 不必 curl：

```bash
./scripts/get-started.sh
```

**手动逐步**（结果相同，控制更细）：见
[docs/getting-started.zh.md](docs/getting-started.zh.md)。

提问后打开 **`/operator`**，再执行
`./scripts/exec.sh sh -c 'EXPERIENCE_MIN_COUNT=1 ./scripts/run-experience-loop.sh all'`。

SETUP_COMPLETE 之后的调用方：[docs/calling.zh.md](docs/calling.zh.md)。

---

## 会创建什么（运营方站点）

| 路径 | 用途 |
|------|------|
| `profiles/<pack>/` | 你的 sources + retrieval-eval 脚手架 |
| `secrets/` | `llm_api_key`、`gh_token`、`a2a_peer_token`（权限 600） |
| `runtime/` | 实例主目录、答案缓存、日志、eval、`examples/` 调用方 |
| `templates/callers/` | FinClaw A2A / MCP / setup-agent 模板 |
| `config/` | 已激活 pack 指针（由 `activate.sh` 写入） |
| `.env` | 非密钥配置 |
| `docker-compose.yml` | 用绑定挂载跑已发布镜像 |

---

## 文档

- [docs/getting-started.zh.md](docs/getting-started.zh.md) · [English](docs/getting-started.md) — 运营方走通（含 `/operator`）
- [docs/calling.zh.md](docs/calling.zh.md) · [English](docs/calling.md) — 先 REST；运营控制台；可选 Agent 调用方
