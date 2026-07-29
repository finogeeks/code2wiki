# Getting started

## Prerequisites

- Docker + Compose v2
- An LLM API key (for real answers; `CASST_MOCK=1` works for plumbing smoke)
- Git remotes you are allowed to clone (public HTTPS or a PAT in `secrets/gh_token`)

## Steps

### 1. Create a site directory

```bash
./scripts/init-site.sh ~/casst-site --pack acme
cd ~/casst-site
```

### 2. Configure the pack

Edit `profiles/acme/sources.yaml` — replace example remotes with yours.
Keep `visibility: private` unless the corpus is intentionally public.

Edit `profiles/acme/retrieval-eval.yaml` with 5–15 real questions.

### 3. Secrets

```bash
printf '%s' 'sk-…' > secrets/llm_api_key
printf '%s' 'ghp_…' > secrets/gh_token   # if needed
chmod 600 secrets/*
```

Optional: set `LLM_PROVIDER` / `LLM_MODEL` in `.env`.

### 4. Image + up

```bash
./scripts/pull-image.sh          # uses CODE2WIKI_IMAGE / VERSION
./scripts/up.sh                  # facade on :8080
./scripts/doctor.sh              # /healthz
```

Local dogfood against a privately built image:

```bash
export CODE2WIKI_IMAGE=code2wiki:dev
./scripts/up.sh
```

### 5. Activate + evaluate (inside the appliance)

```bash
./scripts/activate.sh acme
# optional routing gate (needs retrieval-eval filled):
./scripts/exec.sh ./scripts/casst-retrieval-eval.py
```

### 6. First query (REST — required path)

```bash
./scripts/ask.sh "How do I deploy the product?"
```

### 7. Optional callers

See [calling.md](calling.md) for FinClaw A2A/MCP or Hermes after REST works.
