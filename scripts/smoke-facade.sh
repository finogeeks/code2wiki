#!/usr/bin/env bash
# Facade smoke: healthz + REST ask + A2A card + A2A SendMessage.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ -f .env ]] && set -a && source .env && set +a

# shellcheck disable=SC1091
source "$ROOT/scripts/lib/site-base-url.sh"
PORT="$(grep -E '^CODE2WIKI_PORT=' .env 2>/dev/null | cut -d= -f2- || true)"
PORT="${PORT:-${CODE2WIKI_PORT:-8080}}"
BASE="$(code2wiki_site_base_url "$ROOT")"
export CASST_BASE_URL="$BASE"
TOKEN_FILE="${ROOT}/secrets/a2a_peer_token"
TOKEN="${CASST_A2A_PEER_TOKEN:-}"
PRODUCT="${1:-}"
TIMEOUT="${CODE2WIKI_ASK_TIMEOUT:-180}"
if [[ -z "$TOKEN" && -r "$TOKEN_FILE" ]]; then
  TOKEN="$(tr -d '\r\n' <"$TOKEN_FILE")"
fi

export BASE TOKEN PRODUCT TIMEOUT
python3 <<'PY'
import json, os, sys, urllib.error, urllib.request

base = os.environ["BASE"].rstrip("/")
token = os.environ.get("TOKEN") or ""
product = os.environ.get("PRODUCT") or ""
timeout = int(os.environ.get("TIMEOUT") or "180")
pass_n = fail_n = 0

def ok(name: str) -> None:
    global pass_n
    print(f"OK  {name}")
    pass_n += 1

def bad(name: str, detail: str = "") -> None:
    global fail_n
    print(f"FAIL {name}" + (f": {detail}" if detail else ""), file=sys.stderr)
    fail_n += 1

def http(method: str, path: str, body: dict | None = None, headers: dict | None = None):
    data = None
    hdrs = dict(headers or {})
    if body is not None:
        data = json.dumps(body).encode()
        hdrs.setdefault("content-type", "application/json")
    req = urllib.request.Request(base + path, data=data, headers=hdrs, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            raw = r.read().decode()
            try:
                return r.status, json.loads(raw)
            except json.JSONDecodeError:
                return r.status, raw
    except urllib.error.HTTPError as e:
        raw = e.read().decode(errors="replace")
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            parsed = raw
        detail = parsed if isinstance(parsed, str) else json.dumps(parsed, ensure_ascii=False)
        raise RuntimeError(f"HTTP {e.code}: {detail[:400]}") from e

print(f"==> healthz ({base})")
try:
    st, hz = http("GET", "/healthz")
    if isinstance(hz, dict) and hz.get("ok") is True:
        ok("healthz ok")
    else:
        bad("healthz ok", str(hz)[:200])
except Exception as e:
    bad("healthz ok", str(e))

print("==> REST /v1/ask")
payload = {
    "question": "setup smoke: what sources are registered? Keep it short.",
    "user": "setup-smoke",
}
if product:
    payload["products"] = [product]
try:
    st, ask = http("POST", "/v1/ask", payload)
    if isinstance(ask, dict) and "answer" in ask:
        ok("ask returns answer")
    else:
        bad("ask returns answer", str(ask)[:200])
except Exception as e:
    bad("ask returns answer", str(e))

print("==> A2A agent card")
try:
    st, card = http("GET", "/.well-known/agent-card.json")
    if card:
        ok("a2a card present")
    else:
        bad("a2a card present")
except Exception as e:
    bad("a2a card present", str(e))

print("==> A2A SendMessage")
if not token:
    bad("a2a SendMessage", "no peer token (secrets/a2a_peer_token)")
else:
    body = {
        "jsonrpc": "2.0",
        "id": "setup-1",
        "method": "SendMessage",
        "params": {
            "message": {
                "role": "user",
                "messageId": "setup-1",
                "parts": [
                    {
                        "kind": "text",
                        "text": "Reply with a one-line confirmation that casst is reachable.",
                    }
                ],
            }
        },
    }
    try:
        st, resp = http(
            "POST",
            "/a2a/v1",
            body,
            headers={"authorization": f"Bearer {token}"},
        )
        if isinstance(resp, dict) and "jsonrpc" in resp:
            ok("a2a SendMessage jsonrpc")
        else:
            bad("a2a SendMessage jsonrpc", str(resp)[:200])
    except Exception as e:
        bad("a2a SendMessage jsonrpc", str(e))

print(f"==> summary: {pass_n} passed, {fail_n} failed")
sys.exit(0 if fail_n == 0 else 1)
PY
