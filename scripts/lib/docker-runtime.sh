# shellcheck shell=bash
# Detect container engines and select one for the casst appliance.
#
# Engines offered (when installed / reachable):
#   - Docker contexts (Desktop / OrbStack / Colima / …) → CODE2WIKI_RUNTIME=compose
#   - Apple Container (`container` CLI on macOS)       → CODE2WIKI_RUNTIME=apple
#
# Usage (from get-started after i18n):
#   source scripts/lib/docker-runtime.sh
#   code2wiki_docker_select            # exports CODE2WIKI_RUNTIME (+ DOCKER_CONTEXT)
#   code2wiki_docker_persist_env DIR
#
# Prefer:
#   CODE2WIKI_RUNTIME=apple|compose
#   CODE2WIKI_DOCKER_CONTEXT / DOCKER_CONTEXT / --docker-context
#   CODE2WIKI_DOCKER_NONINTERACTIVE=1

code2wiki_docker_label() {
  case "$1" in
    apple) echo "Apple Container" ;;
    orbstack) echo "OrbStack" ;;
    desktop-linux|desktop-windows|desktop-*) echo "Docker Desktop" ;;
    colima*) echo "Colima" ;;
    default) echo "default (DOCKER_HOST / system socket)" ;;
    *) echo "$1" ;;
  esac
}

code2wiki_docker_cli_ok() {
  command -v docker >/dev/null 2>&1 || return 1
  docker compose version >/dev/null 2>&1 || return 1
  return 0
}

code2wiki_apple_cli_ok() {
  [[ "$(uname -s 2>/dev/null || true)" == "Darwin" ]] || return 1
  command -v container >/dev/null 2>&1 || return 1
  return 0
}

# Ensure Apple Container system services are up (may prompt sudo / take a few seconds).
code2wiki_apple_ensure_system() {
  if container system status >/dev/null 2>&1; then
    return 0
  fi
  echo "$(code2wiki_t docker_apple_starting)"
  if ! container system start; then
    echo "$(code2wiki_t docker_err_apple_start)" >&2
    echo "$(code2wiki_t docker_hint_apple_start)" >&2
    return 1
  fi
  # Brief wait for apiserver.
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    if container system status >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  echo "$(code2wiki_t docker_err_apple_start)" >&2
  return 1
}

code2wiki_docker_install_hint() {
  echo "$(code2wiki_t docker_hint_need)" >&2
  case "$(uname -s 2>/dev/null || echo unknown)" in
    Darwin)
      echo "$(code2wiki_t docker_hint_mac)" >&2
      echo "$(code2wiki_t docker_hint_mac_apple)" >&2
      ;;
    Linux)
      echo "$(code2wiki_t docker_hint_linux)" >&2
      ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT)
      echo "$(code2wiki_t docker_hint_win)" >&2
      ;;
    *)
      echo "$(code2wiki_t docker_hint_generic)" >&2
      ;;
  esac
}

# Unified list:
#   C2W_ENG_IDS[]    — docker context name, or "apple"
#   C2W_ENG_KINDS[]  — compose | apple
#   C2W_ENG_LABELS[]
code2wiki_runtime_scan() {
  C2W_ENG_IDS=()
  C2W_ENG_KINDS=()
  C2W_ENG_LABELS=()

  if code2wiki_docker_cli_ok; then
    local name host i dup current
    current="$(docker context show 2>/dev/null || echo default)"
    local names=()
    if docker context ls >/dev/null 2>&1; then
      while IFS= read -r name; do
        [[ -n "$name" ]] || continue
        names+=("$name")
      done < <(docker context ls --format '{{.Name}}' 2>/dev/null)
    fi
    if [[ ${#names[@]} -eq 0 ]]; then
      names=("$current")
    fi
    local hosts=() ctx_names=() ctx_labels=()
    for name in "${names[@]}"; do
      if ! docker --context "$name" info >/dev/null 2>&1; then
        continue
      fi
      host="$(docker context inspect "$name" --format '{{.Endpoints.docker.Host}}' 2>/dev/null || echo "")"
      host="${host:-unknown:$name}"
      dup=0
      for i in "${!hosts[@]}"; do
        if [[ "${hosts[$i]}" == "$host" ]]; then
          if [[ "${ctx_names[$i]}" == "default" && "$name" != "default" ]]; then
            ctx_names[$i]="$name"
            ctx_labels[$i]="$(code2wiki_docker_label "$name")"
          fi
          dup=1
          break
        fi
      done
      [[ "$dup" == 1 ]] && continue
      hosts+=("$host")
      ctx_names+=("$name")
      ctx_labels+=("$(code2wiki_docker_label "$name")")
    done
    for i in "${!ctx_names[@]}"; do
      C2W_ENG_IDS+=("${ctx_names[$i]}")
      C2W_ENG_KINDS+=("compose")
      C2W_ENG_LABELS+=("${ctx_labels[$i]}")
    done
  fi

  if code2wiki_apple_cli_ok; then
    # Offer Apple Container whenever the CLI is installed; system start happens on apply.
    C2W_ENG_IDS+=("apple")
    C2W_ENG_KINDS+=("apple")
    C2W_ENG_LABELS+=("$(code2wiki_docker_label apple)")
  fi
}

code2wiki_runtime_apply() {
  local id="$1" kind="$2"
  export CODE2WIKI_RUNTIME="$kind"
  if [[ "$kind" == "apple" ]]; then
    unset DOCKER_CONTEXT || true
    code2wiki_apple_ensure_system || return 1
    echo "$(code2wiki_tf docker_using_apple)"
  else
    export DOCKER_CONTEXT="$id"
    unset DOCKER_HOST || true
    echo "$(code2wiki_tf docker_using "$id" "$(code2wiki_docker_label "$id")")"
  fi
}

code2wiki_env_upsert() {
  local envf="$1" key="$2" value="$3"
  [[ -f "$envf" ]] || touch "$envf"
  python3 -c '
import pathlib,sys
path=pathlib.Path(sys.argv[1])
key,value=sys.argv[2],sys.argv[3].replace("\n","").replace("\r","")
lines=path.read_text(encoding="utf-8").splitlines() if path.exists() and path.stat().st_size else []
prefix=key+"="
out=[]; found=False
for line in lines:
    if line.startswith(prefix):
        out.append(prefix+value); found=True
    else:
        out.append(line)
if not found:
    out.append(prefix+value)
path.write_text("\n".join(out)+("\n" if out else ""), encoding="utf-8")
' "$envf" "$key" "$value"
}

code2wiki_docker_persist_env() {
  local root="${1:-.}" envf="${1:-.}/.env"
  local rt="${CODE2WIKI_RUNTIME:-compose}"
  [[ -f "$envf" ]] || touch "$envf"
  code2wiki_env_upsert "$envf" "CODE2WIKI_RUNTIME" "$rt"
  if [[ "$rt" == "compose" && -n "${DOCKER_CONTEXT:-}" ]]; then
    code2wiki_env_upsert "$envf" "DOCKER_CONTEXT" "$DOCKER_CONTEXT"
  fi
}

# Main entry: abort if nothing usable; prompt if several engines.
code2wiki_docker_select() {
  local prefer_ctx="${CODE2WIKI_DOCKER_CONTEXT:-${DOCKER_CONTEXT:-}}"
  local prefer_rt="${CODE2WIKI_RUNTIME:-}"
  local nonint="${CODE2WIKI_DOCKER_NONINTERACTIVE:-0}"
  local current i choice n id kind

  # Flag aliases: --docker-context apple → runtime apple
  if [[ "$prefer_ctx" == "apple" ]]; then
    prefer_rt="apple"
    prefer_ctx=""
  fi

  code2wiki_runtime_scan
  n="${#C2W_ENG_IDS[@]}"

  if [[ "$n" -eq 0 ]]; then
    if ! code2wiki_docker_cli_ok && ! code2wiki_apple_cli_ok; then
      echo "$(code2wiki_t docker_err_no_cli)" >&2
    else
      echo "$(code2wiki_t docker_err_no_daemon)" >&2
    fi
    code2wiki_docker_install_hint
    echo "$(code2wiki_t docker_hint_start_engine)" >&2
    return 1
  fi

  # Explicit runtime preference.
  if [[ "$prefer_rt" == "apple" ]]; then
    for i in "${!C2W_ENG_IDS[@]}"; do
      if [[ "${C2W_ENG_KINDS[$i]}" == "apple" ]]; then
        code2wiki_runtime_apply "apple" "apple"
        return $?
      fi
    done
    echo "$(code2wiki_t docker_err_apple_missing)" >&2
    return 1
  fi
  if [[ "$prefer_rt" == "compose" ]]; then
    # Fall through to docker-context preference / multi-pick among compose only.
    local filtered_ids=() filtered_kinds=() filtered_labels=()
    for i in "${!C2W_ENG_IDS[@]}"; do
      if [[ "${C2W_ENG_KINDS[$i]}" == "compose" ]]; then
        filtered_ids+=("${C2W_ENG_IDS[$i]}")
        filtered_kinds+=("compose")
        filtered_labels+=("${C2W_ENG_LABELS[$i]}")
      fi
    done
    C2W_ENG_IDS=("${filtered_ids[@]}")
    C2W_ENG_KINDS=("${filtered_kinds[@]}")
    C2W_ENG_LABELS=("${filtered_labels[@]}")
    n="${#C2W_ENG_IDS[@]}"
    if [[ "$n" -eq 0 ]]; then
      echo "$(code2wiki_t docker_err_no_daemon)" >&2
      code2wiki_docker_install_hint
      return 1
    fi
  fi

  if [[ -n "$prefer_ctx" ]]; then
    for i in "${!C2W_ENG_IDS[@]}"; do
      if [[ "${C2W_ENG_IDS[$i]}" == "$prefer_ctx" && "${C2W_ENG_KINDS[$i]}" == "compose" ]]; then
        code2wiki_runtime_apply "$prefer_ctx" "compose"
        return 0
      fi
    done
    code2wiki_tf docker_err_ctx_unreachable "$prefer_ctx" >&2
    echo "$(code2wiki_t docker_hint_contexts)" >&2
    for i in "${!C2W_ENG_IDS[@]}"; do
      echo "  - ${C2W_ENG_IDS[$i]}  (${C2W_ENG_LABELS[$i]})" >&2
    done
    return 1
  fi

  if [[ "$n" -eq 1 ]]; then
    code2wiki_runtime_apply "${C2W_ENG_IDS[0]}" "${C2W_ENG_KINDS[0]}"
    return $?
  fi

  current="$(docker context show 2>/dev/null || true)"
  if [[ "$nonint" == 1 ]] || ! code2wiki_can_prompt; then
    for i in "${!C2W_ENG_IDS[@]}"; do
      if [[ "${C2W_ENG_KINDS[$i]}" == "compose" && "${C2W_ENG_IDS[$i]}" == "$current" ]]; then
        code2wiki_runtime_apply "$current" "compose"
        return 0
      fi
    done
    # Prefer first compose engine over apple in CI when ambiguous.
    for i in "${!C2W_ENG_IDS[@]}"; do
      if [[ "${C2W_ENG_KINDS[$i]}" == "compose" ]]; then
        code2wiki_runtime_apply "${C2W_ENG_IDS[$i]}" "compose"
        return 0
      fi
    done
    echo "$(code2wiki_t docker_err_multi_nonint)" >&2
    for i in "${!C2W_ENG_IDS[@]}"; do
      echo "  - ${C2W_ENG_IDS[$i]}  (${C2W_ENG_LABELS[$i]})" >&2
    done
    echo "$(code2wiki_t docker_hint_flag)" >&2
    return 1
  fi

  echo "$(code2wiki_t docker_multi_intro)"
  for i in "${!C2W_ENG_IDS[@]}"; do
    local mark=""
    if [[ "${C2W_ENG_KINDS[$i]}" == "compose" && "${C2W_ENG_IDS[$i]}" == "$current" ]]; then
      mark=" *"
    fi
    printf '  %s) %s — %s%s\n' "$((i + 1))" "${C2W_ENG_IDS[$i]}" "${C2W_ENG_LABELS[$i]}" "$mark"
  done
  echo "  (* = current docker context)"
  local def=1
  for i in "${!C2W_ENG_IDS[@]}"; do
    if [[ "${C2W_ENG_KINDS[$i]}" == "compose" && "${C2W_ENG_IDS[$i]}" == "$current" ]]; then
      def=$((i + 1))
      break
    fi
  done
  choice="$(code2wiki_prompt "$(code2wiki_t docker_pick)" "$def")"
  if [[ ! "$choice" =~ ^[0-9]+$ ]] || [[ "$choice" -lt 1 ]] || [[ "$choice" -gt "$n" ]]; then
    echo "$(code2wiki_t docker_err_bad_pick)" >&2
    return 1
  fi
  i=$((choice - 1))
  code2wiki_runtime_apply "${C2W_ENG_IDS[$i]}" "${C2W_ENG_KINDS[$i]}"
  return $?
}
