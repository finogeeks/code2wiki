# shellcheck shell=bash
# Interactive prompts that work under `curl … | sh` (stdin is the script).
# Prefer /dev/tty; fall back to stdin when it is a TTY.
#
# Note: `[[ -c /dev/tty ]]` alone is not enough — some environments expose
# /dev/tty as a char device that cannot be opened ("Device not configured").

code2wiki_tty_readable() {
  { : </dev/tty; } 2>/dev/null
}

code2wiki_can_prompt() {
  code2wiki_tty_readable || [[ -t 0 ]]
}

code2wiki_prompt() {
  local msg="$1" def="${2:-}" ans=""
  if code2wiki_tty_readable; then
    if [[ -n "$def" ]]; then
      read -r -p "$msg [$def]: " ans </dev/tty || true
    else
      read -r -p "$msg: " ans </dev/tty || true
    fi
  elif [[ -t 0 ]]; then
    if [[ -n "$def" ]]; then
      read -r -p "$msg [$def]: " ans || true
    else
      read -r -p "$msg: " ans || true
    fi
  else
    echo "error: cannot prompt (no TTY); pass flags instead" >&2
    return 1
  fi
  if [[ -n "$ans" ]]; then
    printf '%s' "$ans"
  else
    printf '%s' "$def"
  fi
}
