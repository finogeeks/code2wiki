# shellcheck shell=bash
# Step banners + simple wait spinner for long-running install phases.

# code2wiki_step <n> <total> <msg_key> [printf args…]
code2wiki_step() {
  local n="$1" total="$2" key="$3"
  shift 3
  echo ""
  if [[ $# -gt 0 ]]; then
    echo "==> $(code2wiki_tf step_n "$n" "$total") $(code2wiki_tf "$key" "$@")"
  else
    echo "==> $(code2wiki_tf step_n "$n" "$total") $(code2wiki_t "$key")"
  fi
}

# Poll URL until HTTP success or timeout (seconds). Shows a one-line spinner.
# Sets CODE2WIKI_WAIT_ELAPSED on return. Returns 0 on success.
# code2wiki_wait_http <url> [timeout_sec]
code2wiki_wait_http() {
  local url="$1" timeout="${2:-120}" elapsed=0 spin='|/-\' i=0 c
  CODE2WIKI_WAIT_ELAPSED=0
  _spin_out() {
    if { : >/dev/tty; } 2>/dev/null; then
      printf "$@" >/dev/tty
    else
      printf "$@" >&2
    fi
  }
  while [[ "$elapsed" -lt "$timeout" ]]; do
    if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
      _spin_out '\r\033[K'
      CODE2WIKI_WAIT_ELAPSED="$elapsed"
      return 0
    fi
    c="${spin:i:1}"
    i=$(( (i + 1) % 4 ))
    _spin_out '\r  %s  %ss ' "$c" "$elapsed"
    sleep 2
    elapsed=$((elapsed + 2))
  done
  _spin_out '\r\033[K'
  CODE2WIKI_WAIT_ELAPSED="$elapsed"
  return 1
}
