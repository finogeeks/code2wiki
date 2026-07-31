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

# Resolve the user home directory on macOS / Linux / Windows (Git Bash / MSYS).
code2wiki_home_dir() {
  local h=""
  if [[ -n "${HOME:-}" ]]; then
    h="$HOME"
  elif [[ -n "${USERPROFILE:-}" ]]; then
    h="${USERPROFILE}"
  else
    # Last resort: unquoted ~ is expanded by bash (Git Bash on Windows too).
    h="$(cd ~ && pwd)"
  fi
  # Normalize Windows backslashes for bash path joins / mkdir -p.
  h="${h//\\//}"
  # Drop trailing slash (except root).
  if [[ "$h" != "/" ]]; then
    h="${h%/}"
  fi
  printf '%s' "$h"
}

# Expand a user-typed site path:
#   ~/dir, ~\dir (Windows), bare ~, $HOME/…, ${HOME}/…
# Trim whitespace and optional wrapping quotes.
#
# Important: never use unquoted ${p#~/} — bash tilde-expands that pattern to
# $HOME/, so the strip fails and paths become $HOME/~/… (a literal "~" folder).
code2wiki_expand_path() {
  local p="$1" home rest

  # Trim leading/trailing whitespace.
  p="${p#"${p%%[![:space:]]*}"}"
  p="${p%"${p##*[![:space:]]}"}"

  # Strip one layer of matching quotes if the user typed them.
  if [[ ${#p} -ge 2 ]]; then
    if [[ "$p" == \"*\" || "$p" == \'*\' ]]; then
      p="${p:1:$((${#p} - 2))}"
      p="${p#"${p%%[![:space:]]*}"}"
      p="${p%"${p##*[![:space:]]}"}"
    fi
  fi

  home="$(code2wiki_home_dir)"

  case "$p" in
    '~')
      p="$home"
      ;;
    '~/'* | '~\'*)
      rest="${p:2}"
      rest="${rest//\\//}"
      p="${home}/${rest}"
      ;;
    '$HOME'|'${HOME}')
      p="$home"
      ;;
    '$HOME/'* | '${HOME}/'*)
      if [[ "$p" == '$HOME/'* ]]; then
        rest="${p#\$HOME/}"
      else
        rest="${p#\$\{HOME\}/}"
      fi
      rest="${rest//\\//}"
      p="${home}/${rest}"
      ;;
  esac

  printf '%s' "$p"
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
