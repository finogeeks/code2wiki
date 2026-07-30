# code2wiki

English | [中文](README.zh.md)

Run a **knowledge appliance** that answers questions from *your* product Git
repositories—and let people or other AI agents call it over the network.

This repository is the **customer intake**: host scripts, a Compose template,
and docs. The brains of the system ship as a **Docker image**
(`ghcr.io/finogeeks/code2wiki`). You do not build from this tree.

> Publishing the image to GHCR is a follow-up. For local dogfood, build or load
> an image locally and set `CODE2WIKI_IMAGE` (for example `code2wiki:dev`).

---

## What is this?

Most companies already keep the real product truth in Git: code, design notes,
norms, roadmaps. That truth rarely reaches sales, delivery, pre-sales,
marketing, or executives in a form they can trust. Wikis and decks drift.
Experts become bottlenecks.

**code2wiki** turns selected Git remotes into a living knowledge base and raises
an askable **body double** for that product. We call the double **casst**
(**C**ode **A**s **S**ingle **S**ource of **T**ruth):

- Point it at the repos that define *your* product.
- Ask it questions in natural language (or have another agent ask for you).
- Get answers grounded in those repos—not in a stale brochure someone wrote
  last quarter.

It is **not** “another ChatGPT with your PDF uploaded.” The product under
management is the Git history you configure. Change the remotes, and the
knowledge surface changes with them.

---

## Two sides of the picture

Think of a shop with a storefront and customers.

| Side | Who | Job |
|------|-----|-----|
| **Operator** | You (platform / devops / knowledge owner) | Choose which repos count as truth, deploy the appliance, keep secrets, activate a pack, check health |
| **Caller** | A person, a script, or another AI agent | Ask questions and consume answers—via REST today; later MCP / A2A from FinClaw, Hermes, IDE assistants, etc. |

**This intake repo is for the operator.** It helps you create a site directory
on a host, pull the image, start the container, and prove the facade works with
a simple HTTP ask.

**Caller agents are optional and separate.** Once the facade is up, any client
that speaks the published protocols can call it. You do not need FinClaw or
Hermes on the host to get your first successful answer—REST is enough. Agent
runtimes are *customers of the appliance*, not part of the appliance itself.

```text
  OPERATOR (this repo + your host)              CALLERS (elsewhere)
  ───────────────────────────────               ───────────────────
  profiles / secrets / compose                  humans (curl, ask.sh)
        │                                       peer agents (MCP / A2A)
        ▼                                       IDE / toolchain tools
  Docker image  ──facade :8080──►  answers ◄─── any REST/MCP/A2A client
  (casst + curator + runtime)
```

---

## How it works (working theory)

1. **You declare sources.** In a *pack* under `profiles/<name>/`, you list the
   Git remotes (and eval stubs) that define the product. That pack is the
   operator’s contract: “these repos are the truth.”
2. **You start the appliance.** Compose runs the published image with your site
   directory bind-mounted (`profiles/`, `secrets/`, `runtime/`, `config/`).
   Inside the container, a long-lived agent runtime (FinClaw / `serve`) hosts
   the casst personas and a **facade** that speaks HTTP (and MCP / A2A).
3. **The facade is the only door.** Callers never dig into your Git clones or
   LLM keys. They hit `http://<host>:8080` (or your reverse proxy). The
   appliance retrieves from the configured knowledge, reasons with your LLM
   key, and returns grounded answers.
4. **Warm service, not one-shot chat.** Many people and agents may ask at once.
   The runtime is built as a shared online service (multi-user, concurrent
   requests, cold start paid once)—not as a personal assistant process that
   restarts for every question.
5. **Callers stay dumb about product facts.** A FinClaw or Hermes agent on the
   caller side should *delegate* (“ask casst”) instead of inventing features.
   Grounding stays inside the appliance.

In one line:

> Operators run the truth service; callers only ask. Source of truth = Git.
> Door = facade. Brain = casst inside the image.

---

## Why bother (short)

In digital-heavy orgs, **code increasingly *is* the business**. Sales, delivery,
pre-sales, marketing, engineering—and the agents beside each role—should share
one set of product facts. code2wiki makes that set *askable* without rewriting
another wiki that goes stale.

When the double is useful, the hard part is often **runtime shape** (cold
starts, concurrent callers), not model IQ. That is why the image uses a
service-oriented agent runtime rather than a single-user chat app.

---

## Quick start (operator path)

**One-shot install** — no prior clone, no flags. Run it in a terminal; the
installer asks for site directory, pack name, Git remotes, and secrets:

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/code2wiki/main/install.sh | sh
```

It clones/updates the intake, then walks you through configure → up → activate →
ingest → REST + A2A + FinClaw smokes, and writes
`<site>/runtime/eval/SETUP_COMPLETE.json`.

Optional flags (CI / automation only):

```bash
curl -fsSL https://raw.githubusercontent.com/finogeeks/code2wiki/main/install.sh | sh -s -- \
  --site ~/casst-site --pack acme \
  --repo my-app=https://github.com/org/app.git
```

Prerequisites: Docker + Compose v2 and network access to your Git remotes.
Until GHCR publish lands, after the site exists (or before a resumed `up`):

```bash
echo 'CODE2WIKI_IMAGE=code2wiki:dev' >> ~/casst-site/.env   # use your site path
```

**Already cloned this repo?** Same interactive path without curl:

```bash
./scripts/get-started.sh
```

**Manual steps** (same outcome, more control): see
[docs/getting-started.md](docs/getting-started.md).

After asks: open **`/operator`**, then
`./scripts/exec.sh sh -c 'EXPERIENCE_MIN_COUNT=1 ./scripts/run-experience-loop.sh all'`.

Callers after SETUP_COMPLETE: [docs/calling.md](docs/calling.md)
([中文](docs/calling.zh.md)).

---

## What gets created (operator site)

| Path | Purpose |
|------|---------|
| `profiles/<pack>/` | Your sources + retrieval-eval stubs |
| `secrets/` | `llm_api_key`, `gh_token`, `a2a_peer_token` (mode 600) |
| `runtime/` | Appliance homes, answer-cache, logs, eval, `examples/` callers |
| `templates/callers/` | FinClaw A2A / MCP / setup-agent templates |
| `config/` | Activated pack pointer (written by `activate.sh`) |
| `.env` | Non-secret knobs |
| `docker-compose.yml` | Runs the published image with bind mounts |

---

## Docs

- [docs/getting-started.md](docs/getting-started.md) ([中文](docs/getting-started.zh.md)) — operator walkthrough (includes `/operator`)
- [docs/calling.md](docs/calling.md) ([中文](docs/calling.zh.md)) — REST first; operator console; optional agent callers
