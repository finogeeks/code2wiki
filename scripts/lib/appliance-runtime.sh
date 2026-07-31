# shellcheck shell=bash
# Appliance lifecycle helpers for Compose or Apple Container.
# Requires compose-env.sh already applied (COMPOSE_PROJECT_NAME, CODE2WIKI_RUNTIME).

code2wiki_appliance_name() {
  printf '%s' "${COMPOSE_PROJECT_NAME:-casst-site}-code2wiki"
}

code2wiki_appliance_runtime() {
  printf '%s' "${CODE2WIKI_RUNTIME:-compose}"
}

code2wiki_appliance_image() {
  local ver image
  ver="$(tr -d '[:space:]' < VERSION 2>/dev/null || echo latest)"
  image="${CODE2WIKI_IMAGE:-}"
  if [[ -z "$image" ]]; then
    if [[ "$ver" == "0.0.0-dev" ]]; then
      image="code2wiki:dev"
    else
      image="ghcr.io/finogeeks/code2wiki:${ver}"
    fi
  fi
  printf '%s' "$image"
}

# Exec inside the running appliance. Args: optional -e/--env/--env-file, then command.
code2wiki_appliance_exec() {
  local -a opts=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -e|--env|--env-file)
        opts+=("$1" "${2:-}")
        shift 2
        ;;
      *)
        break
        ;;
    esac
  done
  if [[ "$(code2wiki_appliance_runtime)" == "apple" ]]; then
    container exec "${opts[@]}" "$(code2wiki_appliance_name)" "$@"
  else
    docker compose exec -T "${opts[@]}" code2wiki "$@"
  fi
}

code2wiki_appliance_pull() {
  local image want_pull present is_registry
  image="$(code2wiki_appliance_image)"
  export CODE2WIKI_IMAGE="$image"
  is_registry=0
  [[ "$image" == */* ]] && is_registry=1
  want_pull=0
  if [[ "$is_registry" == 1 ]]; then
    [[ "${CODE2WIKI_PULL:-1}" != "0" ]] && want_pull=1
  else
    [[ "${CODE2WIKI_PULL:-0}" == "1" ]] && want_pull=1
  fi

  if [[ "$(code2wiki_appliance_runtime)" == "apple" ]]; then
    code2wiki_apple_ensure_system || return 1
    present=0
    if container image list 2>/dev/null | grep -qF "$image"; then
      present=1
    elif container image inspect "$image" >/dev/null 2>&1; then
      present=1
    fi
    if [[ "$want_pull" == 1 ]]; then
      if [[ "$present" == 1 ]]; then
        echo "checking registry for updates: $image (Apple Container)"
      else
        echo "pulling $image … (Apple Container)"
      fi
      if ! container image pull --arch amd64 "$image" 2>/dev/null \
        && ! container image pull "$image"; then
        if [[ "$present" == 1 ]]; then
          echo "warning: container image pull failed; continuing with local $image" >&2
        else
          echo "error: cannot pull $image via Apple Container" >&2
          return 1
        fi
      fi
    elif [[ "$present" == 1 ]]; then
      echo "image present (skip pull): $image"
    else
      echo "error: image not found locally: $image" >&2
      echo "hint: container image pull $image   (or set CODE2WIKI_IMAGE)" >&2
      return 1
    fi
  else
    present=0
    docker image inspect "$image" >/dev/null 2>&1 && present=1
    if [[ "$want_pull" == 1 ]]; then
      if [[ "$present" == 1 ]]; then
        echo "checking registry for updates: $image"
      else
        echo "pulling $image …"
      fi
      if ! docker pull "$image"; then
        if [[ "$present" == 1 ]]; then
          echo "warning: docker pull failed; continuing with local image $image" >&2
        else
          echo "error: cannot pull $image" >&2
          return 1
        fi
      fi
    elif [[ "$present" == 1 ]]; then
      echo "image present (skip pull): $image"
    else
      echo "error: image not found locally: $image" >&2
      return 1
    fi
  fi
  echo "CODE2WIKI_IMAGE=$image"
}

code2wiki_appliance_down() {
  local name
  if [[ "$(code2wiki_appliance_runtime)" == "apple" ]]; then
    name="$(code2wiki_appliance_name)"
    container stop "$name" >/dev/null 2>&1 || true
    container rm "$name" >/dev/null 2>&1 || true
    echo "stopped Apple Container: $name"
  else
    docker compose down "$@"
  fi
}

code2wiki_appliance_up() {
  local image port name root
  root="$(pwd)"
  image="$(code2wiki_appliance_image)"
  export CODE2WIKI_IMAGE="$image"
  port="${CODE2WIKI_PORT:-8080}"
  name="$(code2wiki_appliance_name)"

  mkdir -p runtime/{finclaw,hermes,answer-cache,data,bundles,logs,eval,examples} config profiles secrets

  if [[ "$(code2wiki_appliance_runtime)" != "apple" ]]; then
    echo "using image: $image (compose project: ${COMPOSE_PROJECT_NAME})"
    docker compose up -d
    echo "facade: http://127.0.0.1:${port}/healthz"
    return 0
  fi

  code2wiki_apple_ensure_system || return 1

  # Replace any prior instance with the same name.
  container stop "$name" >/dev/null 2>&1 || true
  container rm "$name" >/dev/null 2>&1 || true

  local -a cmd=(
    container run -d
    --name "$name"
    -u 0:0
    -w /workspace/code2wiki
    --arch amd64
  )
  if container run --help 2>&1 | grep -qE -- '--publish([^a-z-]|$)'; then
    cmd+=(--publish "${port}:8080")
  else
    echo "warning: this container CLI has no --publish; use container list/inspect for the IP" >&2
  fi
  if [[ -f .env ]]; then
    cmd+=(--env-file "${root}/.env")
  fi
  # Apple Container bind-mounts secret *files* poorly; inject as env (entrypoint contract).
  if [[ -z "${GH_TOKEN:-}" && -r secrets/gh_token ]]; then
    cmd+=(-e "GH_TOKEN=$(tr -d '\r\n' <"${root}/secrets/gh_token")")
  fi
  if [[ -z "${LLM_API_KEY:-}" && -r secrets/llm_api_key ]]; then
    cmd+=(-e "LLM_API_KEY=$(tr -d '\r\n' <"${root}/secrets/llm_api_key")")
  fi
  if [[ -z "${CASST_A2A_PEER_TOKEN:-}" && -r secrets/a2a_peer_token ]]; then
    cmd+=(-e "CASST_A2A_PEER_TOKEN=$(tr -d '\r\n' <"${root}/secrets/a2a_peer_token")")
  fi
  if [[ -z "${GITHUB_TOKEN:-}" ]]; then
    if [[ -n "${GH_TOKEN:-}" ]]; then
      cmd+=(-e "GITHUB_TOKEN=${GH_TOKEN}")
    elif [[ -r secrets/gh_token ]]; then
      cmd+=(-e "GITHUB_TOKEN=$(tr -d '\r\n' <"${root}/secrets/gh_token")")
    fi
  fi
  cmd+=(
    -e "CODE2WIKI_HOME=/workspace/code2wiki"
    -e "CASST_PUBLIC_BASE_URL=${CASST_PUBLIC_BASE_URL:-http://127.0.0.1:${port}}"
    -v "${root}/profiles:/workspace/code2wiki/profiles"
    -v "${root}/config:/workspace/code2wiki/config"
    -v "${root}/secrets:/workspace/code2wiki/secrets"
    -v "${root}/runtime/finclaw:/var/lib/code2wiki/finclaw"
    -v "${root}/runtime/hermes:/var/lib/code2wiki/hermes"
    -v "${root}/runtime/answer-cache:/var/lib/code2wiki/answer-cache"
    -v "${root}/runtime/data:/var/lib/code2wiki/data"
    -v "${root}/runtime/bundles:/var/lib/code2wiki/bundles"
    -v "${root}/runtime/logs:/workspace/code2wiki/runtime/logs"
    -v "${root}/runtime/eval:/workspace/code2wiki/runtime/eval"
    "$image"
    mcp
  )

  echo "using image: $image (Apple Container: $name)"
  "${cmd[@]}"
  echo "facade: http://127.0.0.1:${port}/healthz"
}
