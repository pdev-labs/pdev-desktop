#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# --- Fast-init cache ---------------------------------------------------------
# Static integration scripts are cached under ~/.cache/shell-init and only
# regenerated when the underlying binary changes. Saves ~50 ms per new shell.
__SHELL_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/shell-init"
__cache_init() {
  local _ci_name="$1" _ci_bin="$2"
  shift 2
  local _ci_binpath _ci_cache _ci_tmp
  _ci_binpath=$(command -v "$_ci_bin") || return 0
  _ci_cache="$__SHELL_CACHE/$_ci_name.bash"
  if [[ ! -s "$_ci_cache" || "$_ci_binpath" -nt "$_ci_cache" ]]; then
    mkdir -p "$__SHELL_CACHE" || return 0
    _ci_tmp="$_ci_cache.$$"
    if "$@" >"$_ci_tmp" 2>/dev/null; then
      mv -f "$_ci_tmp" "$_ci_cache"
    else
      rm -f "$_ci_tmp"
      return 0
    fi
  fi
  source "$_ci_cache"
}

# fzf's Bash integration also binds Ctrl+R to its history picker. We want
# Bash's native reverse-search-history, so strip just that binding while
# caching the rest of the integration.
__cache_fzf() {
  local _cf_bin _cf_cache _cf_tmp
  _cf_bin=$(command -v fzf) || return 0
  _cf_cache="$__SHELL_CACHE/fzf-native.bash"
  if [[ ! -s "$_cf_cache" || "$_cf_bin" -nt "$_cf_cache" ]]; then
    mkdir -p "$__SHELL_CACHE" || return 0
    _cf_tmp="$_cf_cache.$$"
    if fzf --bash 2>/dev/null | command grep -vF '"\C-r"' >"$_cf_tmp"; then
      mv -f "$_cf_tmp" "$_cf_cache"
    else
      rm -f "$_cf_tmp"
      return 0
    fi
  fi
  source "$_cf_cache"
}

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

# opencode
export PATH=/home/pdev/.opencode/bin:$PATH

# Node.js (installed locally, no root required)
export PATH="$HOME/.local/node/bin:$PATH"
export PATH="$HOME/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
alias ls=lsd
c() {
  "$@" | wl-copy
}
if command -v zoxide >/dev/null 2>&1 && [[ -z ${__ZOXIDE_INITIALIZED-} ]]; then
  __cache_init zoxide zoxide zoxide init bash
  __ZOXIDE_INITIALIZED=1
fi

# OmniRoute AI gateway — credentials live in a 0600 file.
[ -f "$HOME/.config/omniroute/env" ] && . "$HOME/.config/omniroute/env"

# =============================================================================
#  Shell quality — history, Starship, small shortcuts
# =============================================================================
# History: shared between tmux panes, deduplicated, timestamped.
HISTSIZE=50000
HISTFILESIZE=100000
HISTCONTROL=ignoreboth:erasedups
HISTIGNORE='ls:ll:la:lt:cd:pwd:clear:exit'
HISTTIMEFORMAT='%F %T  '
shopt -s histappend checkwinsize

# Flush each command immediately so panes don't overwrite each other.
# Must be set before the prompt hook captures it.
PROMPT_COMMAND="history -a${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# Starship prompt (pacman package, or ~/.local/bin if installed there)
if command -v starship >/dev/null 2>&1; then
  export STARSHIP_SHELL=bash

  # Preserve the history/zoxide hooks registered above.
  if [[ -z ${__starship_prompt_hook+x} ]]; then
    if [[ "$(declare -p PROMPT_COMMAND 2>&1)" == "declare -a"* ]]; then
      printf -v __starship_prompt_hook '%s; ' "${PROMPT_COMMAND[@]}"
    else
      __starship_prompt_hook="${PROMPT_COMMAND-}"
    fi
  fi

  # Record command start in microseconds. No subprocess, unlike Starship's
  # stock Bash preexec, which spawns `starship time` before every command.
  __starship_preexec() {
    [[ ${__starship_ready-} == 1 ]] || return 0
    __starship_ready=0
    __starship_start=${EPOCHREALTIME//[!0-9]/}
  }
  trap '__starship_preexec' DEBUG

  __starship_prompt() {
    local status=$? now=${EPOCHREALTIME//[!0-9]/} duration=0
    if [[ -n ${__starship_start-} && $now -gt $__starship_start ]]; then
      duration=$(( (now - __starship_start) / 1000 ))
    fi
    if [[ -n ${__starship_prompt_hook-} ]]; then
      eval "$__starship_prompt_hook"
    fi
    local args=(prompt --status="$status")
    (( duration >= 1000 )) && args+=(--cmd-duration="$duration")
    PS1="$(starship "${args[@]}")"
    __starship_ready=1
    __starship_start=
    return "$status"
  }
  __starship_ready=0
  unset PROMPT_COMMAND
  PROMPT_COMMAND=__starship_prompt
  # Match Starship's continuation prompt without spawning starship at startup.
  PS2=$'\[\e[90m\]↳\[\e[0m\] '
fi

# Responsive fastfetch: pick a logo and module set that fit the terminal.
# A tiled Hyprland window reserves space for the next split, so opening more
# terminals does not reflow existing ff output into a wrapped mess.
# Set FF_SAFE=0 to use the actual current size instead.
__ff_effective_geometry() {
  local cols lines geom
  cols=$(tput cols 2>/dev/null || true)
  lines=$(tput lines 2>/dev/null || true)
  [[ $cols =~ ^[0-9]+$ ]] || cols=${COLUMNS:-80}
  [[ $lines =~ ^[0-9]+$ ]] || lines=${LINES:-24}
  if (( cols >= 55 )) &&
     [[ -z ${TMUX:-}${STY:-} && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} && ${FF_SAFE:-1} != 0 ]] &&
     command -v hyprctl >/dev/null 2>&1 &&
     command -v python3 >/dev/null 2>&1; then
    geom=$(python3 "$HOME/.config/fastfetch/safe-width.py" "$cols" "$lines" "$$" 2>/dev/null || true)
    if [[ $geom =~ ^([0-9]+)[[:space:]]+([0-9]+)$ ]]; then
      cols=${BASH_REMATCH[1]}
      lines=${BASH_REMATCH[2]}
    fi
  fi
  printf '%s %s\n' "$cols" "$lines"
}

__ff_layout() {
  local cols lines geom
  geom=$(__ff_effective_geometry)
  read -r cols lines <<< "$geom"
  if (( cols < 24 || lines < 12 )); then
    printf '%s' 'none|nano'
  elif (( cols < 28 )); then
    printf '%s' 'none|mini'
  elif (( cols < 33 )); then
    printf '%s' 'none|micro'
  elif (( cols < 40 )); then
    printf '%s' 'none|minimal'
  elif (( cols < 55 )); then
    printf '%s' 'none|compact'
  elif (( cols < 58 || lines < 16 )); then
    printf '%s' 'tiny|minimal'
  elif (( cols < 70 || lines < 20 )); then
    printf '%s' 'small|compact-lite'
  elif (( cols < 95 || lines < 22 )); then
    printf '%s' 'small|compact'
  elif (( cols < 115 || lines < 22 )); then
    printf '%s' 'medium|compact'
  elif (( cols < 125 || lines < 27 )); then
    printf '%s' 'medium|full'
  else
    printf '%s' 'large|full'
  fi
}

fastfetch() {
  local layout logo structure arg
  local args=()
  for arg in "$@"; do
    case "$arg" in
      -c|--config|--config=*|--logo|--logo=*|--file-raw|--file-raw=*|--structure|--structure=*|--structure-disabled|--structure-disabled=*|-h|--help|--version)
        command fastfetch "$@"
        return
        ;;
    esac
  done
  layout=$(__ff_layout)
  logo=${layout%%|*}
  structure=${layout#*|}
  args=(-c "$HOME/.config/fastfetch/config.jsonc")
  if [[ $logo == none ]]; then
    args+=(--logo none)
  else
    args+=(--file-raw "$HOME/.config/fastfetch/mark-$logo.ansi")
  fi
  case "$structure" in
    nano) args+=(--structure 'title:os:shell') ;;
    mini) args+=(--structure 'title:os:uptime:shell') ;;
    micro) args+=(--structure 'title:os:kernel:uptime:shell') ;;
    minimal) args+=(--structure 'title:os:kernel:uptime:packages:shell:wm:memory:localip') ;;
    compact-lite) args+=(--structure 'title:os:kernel:uptime:packages:shell:wm:memory:swap:localip') ;;
    compact) args+=(--structure 'title:os:kernel:uptime:packages:shell:wm:memory:swap:disk:localip:battery') ;;
  esac
  command fastfetch "${args[@]}"
}
alias ff='fastfetch'

# Show fastfetch once per new terminal window (uncomment to enable):
# if [ -z "${TMUX:-}" ] && [ -z "${FASTFETCH_SHOWN:-}" ]; then
#   export FASTFETCH_SHOWN=1
#   fastfetch
# fi


# =============================================================================
#  Power layer — completion, color, fuzzy find, utilities
# =============================================================================

# --- Readline ---------------------------------------------------------------
bind 'set completion-ignore-case on'
# Tab once completes the common prefix; a second Tab lists the matches.
# (show-all-if-ambiguous would dump every match on the first Tab.)
bind 'set show-all-if-ambiguous off'
bind 'set show-all-if-unmodified on'
bind '"\C-i": complete'
bind 'set colored-stats on'
bind 'set colored-completion-prefix on'
bind 'set menu-complete-display-prefix on'
# Up/Down search history by the current prefix instead of walking everything
bind '"\e[A": history-search-backward'
bind '"\e[B": history-search-forward'
shopt -s globstar

# --- File listing colors ----------------------------------------------------
# lsd takes file-type colors from LS_COLORS; keep coreutils' map, then override
# the core entries so listings match the Graphite palette.
if command -v dircolors >/dev/null 2>&1; then
  __cache_init dircolors dircolors dircolors -b
  LS_COLORS="${LS_COLORS}:di=38;5;111:fi=38;5;252:ln=38;5;116:ex=38;5;150:or=38;5;210:mi=38;5;210"
  export LS_COLORS
fi

alias ll='lsd -l'
alias la='lsd -la'
alias lt='lsd --tree'

# --- fzf: fuzzy history, files, directories --------------------------------
if command -v fzf >/dev/null 2>&1; then
  export FZF_DEFAULT_OPTS="
    --height=60%
    --layout=reverse
    --border=rounded
    --border-label=' fzf '
    --info=inline
    --prompt='❯ '
    --pointer='▶'
    --marker='✓'
    --color=fg:#d7dae1,bg:#17181d,hl:#7aa2f7
    --color=fg+:#f2f4f8,bg+:#23262e,hl+:#7ad6e0
    --color=info:#8a909c,prompt:#7aa2f7,pointer:#7ad6e0
    --color=marker:#a9d98a,spinner:#f0cf8e,header:#8a909c
    --color=border:#3a3f4b
  "
  if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
  elif command -v rg >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  fi
  if command -v bat >/dev/null 2>&1; then
    export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always --line-range :200 -- {}'"
  else
    export FZF_CTRL_T_OPTS="--preview 'sed -n \"1,200p\" -- {}'"
  fi
  if command -v lsd >/dev/null 2>&1; then
    export FZF_ALT_C_OPTS="--preview 'lsd --tree --depth 1 --color=always -- {}'"
  fi
  # Keep bash's native Ctrl+R; fzf owns Ctrl+T and Alt+C only.
  bind -r '"\C-r"'
  bind '"\C-r": reverse-search-history'

  # Alt+C: jump to a directory with a tree preview (own binding; reliable).
  fcd() {
    local dir
    dir=$(find . -type d -not -path '*/.*' -not -path '*/node_modules/*' 2>/dev/null \
      | fzf --prompt='cd ❯ ') && cd -- "$dir"
  }
  bind -x '"\ec": fcd'

  # Ctrl+T loads fzf's integration on first use. Sourcing its 29 KB script at
  # every shell start cost ~33 ms; this keeps startup fast.
  __fzf_file_widget() {
    if ! declare -F fzf-file-widget >/dev/null 2>&1; then
      __cache_fzf
      # fzf's integration rebinds Ctrl+R and Alt+C; restore our choices.
      bind -r '"\C-r"'
      bind '"\C-r": reverse-search-history'
      bind -x '"\ec": fcd'
    fi
    declare -F fzf-file-widget >/dev/null 2>&1 && fzf-file-widget
  }
  bind -x '"\C-t": __fzf_file_widget'
fi

# --- bat --------------------------------------------------------------------
if command -v bat >/dev/null 2>&1; then
  export BAT_THEME=graphite
  alias cat='bat --style=plain --paging=never'
fi

# --- Man pages --------------------------------------------------------------
export LESS='-R'
export MANPAGER='less -R'
export LESS_TERMCAP_mb=$'\e[1;38;2;255;123;134m'
export LESS_TERMCAP_md=$'\e[1;38;2;122;162;247m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_so=$'\e[38;2;240;207;142m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_us=$'\e[4;38;2;122;214;224m'
export LESS_TERMCAP_ue=$'\e[0m'

# --- Small utilities --------------------------------------------------------
mkcd() { mkdir -p -- "$1" && cd -- "$1"; }
serve() { python3 -m http.server "${1:-8000}"; }
ports() { ss -tulpn; }

if command -v fzf >/dev/null 2>&1; then
  fkill() {
    local pid
    pid=$(ps -eo pid=,comm=,args= | fzf --header=' kill process ' | awk '{print $1}')
    [ -n "$pid" ] && kill -TERM "$pid" && echo "SIGTERM -> $pid"
  }
fi

# --- tmux project sessionizer ------------------------------------------------
# ts [root] — pick a directory, create or switch to a tmux session named after it.
if command -v fzf >/dev/null 2>&1 && command -v tmux >/dev/null 2>&1 && command -v fd >/dev/null 2>&1; then
  ts() {
    local root dir name
    root="${1:-$HOME/developer}"
    dir=$(fd --type d --hidden --follow --exclude .git --max-depth 3 . "$root" 2>/dev/null \
      | fzf --prompt='session ❯ ')
    [ -z "$dir" ] && return
    name=$(basename "$dir")
    if [ -n "${TMUX:-}" ]; then
      tmux new-session -Ads "$name" -c "$dir" 2>/dev/null
      tmux switch-client -t "$name"
    else
      tmux new-session -As "$name" -c "$dir"
    fi
  }
fi

# --- Git --------------------------------------------------------------------
alias gst='git status -sb'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate -20'
alias gco='git checkout'
FF_SAFE=0
