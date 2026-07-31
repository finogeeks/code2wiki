# shellcheck shell=bash
# Locale detection + message lookup for public intake scripts.
# Override: CODE2WIKI_LANG=en|zh  (also accepts zh_CN, en_US, …)

code2wiki_detect_lang() {
  local raw="${CODE2WIKI_LANG:-}"
  if [[ -z "$raw" ]]; then
    raw="${LC_MESSAGES:-${LANG:-${LC_ALL:-}}}"
  fi
  raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    zh | zh_* | zh.* | *_zh | *_zh.* | chinese*)
      printf '%s' "zh"
      ;;
    *)
      printf '%s' "en"
      ;;
  esac
}

# Load en first (fallback), then active language overlays.
code2wiki_i18n_init() {
  local dir lang
  dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/i18n"
  lang="$(code2wiki_detect_lang)"
  CODE2WIKI_UI_LANG="$lang"
  export CODE2WIKI_UI_LANG
  # shellcheck disable=SC1090
  [[ -f "$dir/en.sh" ]] && source "$dir/en.sh"
  if [[ "$lang" != "en" && -f "$dir/${lang}.sh" ]]; then
    # shellcheck disable=SC1090
    source "$dir/${lang}.sh"
  fi
}

# Lookup key → string (indirect expansion; bash 3.2+ safe).
code2wiki_t() {
  local key="$1"
  local var="C2W_${key}"
  printf '%s' "${!var:-$key}"
}

# printf-style: code2wiki_tf key arg…
code2wiki_tf() {
  local key="$1" fmt
  shift
  fmt="$(code2wiki_t "$key")"
  # shellcheck disable=SC2059
  printf "$fmt" "$@"
}
