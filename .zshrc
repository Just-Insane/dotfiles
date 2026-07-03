# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
# Skip instant prompt in VS Code — it buffers shell startup output, causing
# Copilot agent terminals to read stale buffered output instead of command output.
if [[ "$TERM_PROGRAM" != "vscode" ]] && [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Deduplicate PATH entries automatically - zsh ties the `path` array to $PATH,
# so this silently drops duplicates whenever PATH is modified.
typeset -U path PATH

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
# ZSH_THEME="robbyrussell"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# Disable OMZ auto-update in VS Code terminals — the update check does a git
# fetch over SSH which can hang in restricted agent environments.
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
    zstyle ':omz:update' mode disabled
else
    zstyle ':omz:update' mode auto      # update automatically without asking
fi

# Uncomment the following line to change how often to auto-update (in days).
zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# Disabled in VS Code — ZSH correction prompts "correct x to y? [nyae]" which
# hangs agent terminals waiting for user input.
[[ "$TERM_PROGRAM" != "vscode" ]] && ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
#plugins=(git) # Commented_Out

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_ALL_DUPS   # don't record duplicate consecutive entries
setopt HIST_REDUCE_BLANKS     # remove extra blanks from history entries
setopt SHARE_HISTORY          # share history immediately between sessions
setopt HIST_VERIFY            # show history expansion (!! etc) before executing

# Auto-install custom OMZ plugins if missing (one-time git clone per machine)
_zsh_custom=${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}
[[ -d "$_zsh_custom/plugins/zsh-autosuggestions" ]] || \
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        "$_zsh_custom/plugins/zsh-autosuggestions" 2>/dev/null
[[ -d "$_zsh_custom/plugins/fast-syntax-highlighting" ]] || \
    git clone --depth=1 https://github.com/zdharma-continuum/fast-syntax-highlighting \
        "$_zsh_custom/plugins/fast-syntax-highlighting" 2>/dev/null
[[ -d "$_zsh_custom/plugins/you-should-use" ]] || \
    git clone --depth=1 https://github.com/MichaelAquilina/zsh-you-should-use.git \
        "$_zsh_custom/plugins/you-should-use" 2>/dev/null
unset _zsh_custom

# Prevent tmux plugin from auto-starting a new tmux session (already inside tmux)
ZSH_TMUX_AUTOSTART=false
ZSH_TMUX_AUTOCONNECT=false

# In VS Code: use a minimal plugin set to avoid network/daemon hangs during init.
# Excluded: git-auto-fetch (SSH fetch), github (API calls), rbw (Bitwarden server),
#           dotenv (arbitrary .env sourcing), emacs (daemon socket), repo (network).
# GIT_AUTO_FETCH_INTERVAL=0 is set globally so agent/sub-shells also skip SSH fetch.
GIT_AUTO_FETCH_INTERVAL=0
if [[ "$TERM_PROGRAM" == "vscode" ]]; then
    plugins=(
      common-aliases
      git
      gitignore
      history
      safe-paste
      zsh-autosuggestions
      fast-syntax-highlighting
      history-substring-search
    )
else
    plugins=(
      aliases
      brew
      command-not-found
      common-aliases
      copyfile
      cp
      dircycle
      dotenv
      emacs
      encode64
      extract
      git
      github
      gitignore
      history
      kubectl
      macos
      postgres
      python
      rbw
      repo
      rsync
      safe-paste
      tmux
      web-search
      zsh-autosuggestions
      zsh-interactive-cd
      you-should-use
      fast-syntax-highlighting
      history-substring-search  # must come after fast-syntax-highlighting
    )
    # Load iTerm2 shell integration only when actually running in iTerm2
    [[ "$TERM_PROGRAM" == "iTerm.app" ]] && plugins+=(iterm2)
fi

# Cache zsh completions to disk - avoids recomputing on every shell start
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/completion-cache"

ZSH_THEME="powerlevel10k/powerlevel10k"
source $ZSH/oh-my-zsh.sh

# history-substring-search: type a prefix then press Up/Down to cycle matching history
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down

# Emacs paths
export PATH="/usr/texbin:$PATH"
export PATH="$HOME/.config/emacs/bin:$PATH"

# User specific environment
if ! [[ "$PATH" =~ "$HOME/.local/bin:$HOME/bin:" ]]
then
    PATH="$HOME/.local/bin:$HOME/bin:$PATH"
fi

# GO paths - hardcoded to avoid brew --prefix subprocess on every shell start
export GOPATH=$HOME/go
export GOROOT="/opt/homebrew/opt/go/libexec"
export PATH="$PATH:${GOPATH}/bin:${GOROOT}/bin"

# NVM paths - lazy load for faster shell startup (~500ms saved per terminal)
export NVM_DIR="$HOME/.nvm"
_load_nvm() {
    unset -f nvm node npm npx pnpm
    [ -s "$(brew --prefix nvm)/nvm.sh" ] && \. "$(brew --prefix nvm)/nvm.sh"
    [ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"
}
nvm()  { _load_nvm; nvm  "$@"; }
node() { _load_nvm; node "$@"; }
npm()  { _load_nvm; npm  "$@"; }
npx()  { _load_nvm; npx  "$@"; }
pnpm() { _load_nvm; pnpm "$@"; }

# export ALTERNATE_EDITOR=""
export EDITOR="emacsclient -t"           # $EDITOR opens in terminal
export VISUAL="emacsclient -c -a emacs"  # $VISUAL opens in GUI mode
export ALTERNATE_EDITOR=""

alias ec="emacsclient -c -a emacs -n"
alias et="emacsclient -t"
#alias emacs="emacsclient -c -a emacs -n"

alias config='/usr/bin/git --git-dir=$HOME/.cfg/ --work-tree=$HOME'

# https://github.com/drduh/YubiKey-Guide#replace-agents
export GPG_TTY="$(tty)"
if [[ "$TERM_PROGRAM" != "vscode" ]]; then
    gpgconf --launch gpg-agent
    export SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
else
    # In VS Code: gpgconf may hang if the agent is in a bad state.
    # Use a static well-known socket path instead of querying gpgconf.
    export SSH_AUTH_SOCK="${GNUPGHOME:-$HOME/.gnupg}/S.gpg-agent.ssh"
fi

export PYENV_ROOT="$HOME/.pyenv"
command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"

# Clean up stale pyenv rehash lock on every shell start.
# pyenv rehash finishes in <5s; any surviving lock is orphaned (killed process).
# Removing it here is safe — no pyenv rehash spans across shell starts.
rm -f "${PYENV_ROOT:-$HOME/.pyenv}/shims/.pyenv-shim" 2>/dev/null

# Cache pyenv init output - regenerate only when the pyenv binary changes
_pyenv_init_cache="${XDG_CACHE_HOME:-$HOME/.cache}/pyenv-init.zsh"
if command -v pyenv >/dev/null; then
    if [[ ! -f "$_pyenv_init_cache" ]] || [[ "$(command -v pyenv)" -nt "$_pyenv_init_cache" ]]; then
        pyenv init --no-rehash - zsh > "$_pyenv_init_cache" 2>/dev/null
    fi
    source "$_pyenv_init_cache"
fi
unset _pyenv_init_cache

# eval $(thefuck --alias fuck)
alias powershell="pwsh"
alias lg="lazygit"

# gh: GitHub CLI shortcuts
alias prl="gh pr list"
alias prv="gh pr view --web"
alias prc="gh pr create"
alias ghr="gh repo view --web"

# mkcd: create a directory and cd into it
mkcd() { mkdir -p "$@" && cd "$_"; }

# k9s: Kubernetes TUI (brew install k9s)
if command -v k9s >/dev/null; then
    alias k='k9s'
fi

# tealdeer: practical command examples (brew install tealdeer)
if command -v tldr >/dev/null; then
    alias help='tldr'
fi

# xh: modern HTTP client — cleaner syntax than curl (brew install xh)
# Usage: xh POST api.example.com/endpoint key=value
# Wire xh to use https by default for bare hostnames
export XH_HTTPS=true

# git worktree shortcuts — check out two branches simultaneously
alias gwl='git worktree list'
alias gwa='git worktree add'
alias gwr='git worktree remove'

# bat: cat with syntax highlighting (brew install bat)
# Disabled in VS Code - bat's ANSI/decoration output breaks Copilot agent terminal reads
if [[ "$TERM_PROGRAM" != "vscode" ]] && command -v bat >/dev/null; then
    alias cat='bat --style=plain --pager=never'
    export MANPAGER="sh -c 'col -bx | bat -l man -p'"
    export BAT_THEME="Solarized (dark)"
fi

# eza: modern ls with icons (brew install eza)
# Disabled in VS Code - icons require Nerd Font; may not render in all VS Code terminals
if [[ "$TERM_PROGRAM" != "vscode" ]] && command -v eza >/dev/null; then
    alias ls='eza'
    alias ll='eza -la --icons --git --group-directories-first --time-style=long-iso'
    alias la='eza -la --icons --git --group-directories-first --time-style=long-iso'
    alias lt='eza --tree --icons --git-ignore'
fi

# dust: visual disk usage tree (brew install dust)
# --reverse: show largest at bottom so biggest offenders are visible without scrolling
if command -v dust >/dev/null; then
    alias du='dust --reverse'
fi

# cp → rsync: archive mode preserves permissions/timestamps/symlinks; shows progress
# Use \cp or command cp to bypass when you need plain cp behaviour
alias cp='rsync -ah --progress'

# rg: ripgrep replaces grep - faster, respects .gitignore, Unicode-aware
# --smart-case: case-insensitive unless the pattern contains uppercase
# Disabled in VS Code — rg rejects GNU grep flags (e.g. -E encoding arg), breaking
# agent/script commands that call grep with standard flags.
if [[ "$TERM_PROGRAM" != "vscode" ]] && command -v rg >/dev/null; then
    alias grep='rg --smart-case'
fi

# xh: modern curl replacement - cleaner syntax, auto-detects JSON
# --follow: follow redirects (off by default in curl); --timeout: fail fast
if command -v xh >/dev/null; then
    alias curl='xh --follow --timeout=30'
fi

# btop: modern top with graphs and mouse support
if command -v btop >/dev/null; then
    alias top='btop'
fi

# delta: syntax-highlighted diff (also used as git pager)
# Note: delta reads unified diff format from stdin or takes two files directly
if command -v delta >/dev/null; then
    alias diff='delta'
fi

# fd: fast find replacement - respects .gitignore, simpler syntax
# ⚠ syntax differs: `fd pattern` vs `find . -name pattern`; use \find to bypass
# Disabled in VS Code — fd syntax is incompatible with POSIX find flags used by
# agent/script commands.
if [[ "$TERM_PROGRAM" != "vscode" ]] && command -v fd >/dev/null; then
    alias find='fd'
fi

# duf: disk usage by filesystem (replaces df)
# OMZ common-aliases sets duf='du -sh *' which would intercept — unalias it first
if command -v duf >/dev/null; then
    unalias duf 2>/dev/null
    alias df='duf'
fi

vterm_printf() {
    if [ -n "$TMUX" ] && ([ "${TERM%%-*}" = "tmux" ] || [ "${TERM%%-*}" = "screen" ]); then
        # Tell tmux to pass the escape sequences through
        printf "\ePtmux;\e\e]%s\007\e\\" "$1"
    elif [ "${TERM%%-*}" = "screen" ]; then
        # GNU screen (screen, screen-256color, screen-256color-bce)
        printf "\eP\e]%s\007\e\\" "$1"
    else
        printf "\e]%s\e\\" "$1"
    fi
}

export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt

# Cache direnv hook output - regenerate only when the direnv binary changes
_direnv_cache="${XDG_CACHE_HOME:-$HOME/.cache}/direnv-hook.zsh"
if command -v direnv >/dev/null; then
    if [[ ! -f "$_direnv_cache" ]] || [[ "$(command -v direnv)" -nt "$_direnv_cache" ]]; then
        direnv hook zsh > "$_direnv_cache" 2>/dev/null
    fi
    source "$_direnv_cache"
fi
unset _direnv_cache

# Created by `pipx` on 2023-10-15 02:36:24
export PATH="$PATH:$HOME/.local/bin"

# flux completions - cached to avoid regenerating on every shell start
_flux_completion_cache="${XDG_CACHE_HOME:-$HOME/.cache}/flux-completion.zsh"
if command -v flux >/dev/null; then
    if [[ ! -f "$_flux_completion_cache" ]] || [[ -n "$(find "$_flux_completion_cache" -mtime +7 2>/dev/null)" ]]; then
        flux completion zsh > "$_flux_completion_cache" 2>/dev/null
    fi
    [[ -f "$_flux_completion_cache" ]] && source "$_flux_completion_cache"
fi
unset _flux_completion_cache

# kubectl completions - cached to avoid regenerating on every shell start
_kubectl_completion_cache="${XDG_CACHE_HOME:-$HOME/.cache}/kubectl-completion.zsh"
if command -v kubectl >/dev/null; then
    if [[ ! -f "$_kubectl_completion_cache" ]] || [[ -n "$(find "$_kubectl_completion_cache" -mtime +7 2>/dev/null)" ]]; then
        kubectl completion zsh > "$_kubectl_completion_cache" 2>/dev/null
    fi
    [[ -f "$_kubectl_completion_cache" ]] && source "$_kubectl_completion_cache"
fi
unset _kubectl_completion_cache

# Cache zoxide init output - regenerate only when the zoxide binary changes
_zoxide_cache="${XDG_CACHE_HOME:-$HOME/.cache}/zoxide-init.zsh"
if command -v zoxide >/dev/null; then
    if [[ ! -f "$_zoxide_cache" ]] || [[ "$(command -v zoxide)" -nt "$_zoxide_cache" ]]; then
        zoxide init zsh --cmd cd > "$_zoxide_cache" 2>/dev/null
    fi
    source "$_zoxide_cache"
fi
unset _zoxide_cache

# atuin - history on steroids (brew install atuin)
# Replaces Ctrl+R with fuzzy search, timestamps, per-directory/host filtering
_atuin_cache="${XDG_CACHE_HOME:-$HOME/.cache}/atuin-init.zsh"
if command -v atuin >/dev/null; then
    if [[ ! -f "$_atuin_cache" ]] || [[ "$(command -v atuin)" -nt "$_atuin_cache" ]]; then
        atuin init zsh > "$_atuin_cache" 2>/dev/null
    fi
    source "$_atuin_cache"
fi
unset _atuin_cache

# fzf completions
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Wire fzf to use fd - faster, respects .gitignore, finds hidden files
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_DEFAULT_OPTS='--height 40% --layout=reverse --border'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# -- Default tmux session ------------------------------------------------------
# Auto-create the "Default" session with four general-purpose windows.
_create_default_tmux_session() {
  [[ "$TERM_PROGRAM" == "vscode" ]] && return
  [[ -n "$TMUX" ]] && return
  command -v tmux >/dev/null 2>&1 || return

  tmux has-session -t Default 2>/dev/null && return

  # 1. General
  tmux new-session -d -s Default -n General -c "$HOME"

  # 2. Charm
  tmux new-window -t Default -n Charm -c "$HOME/git/Charm"

  # 3. MDAD
  tmux new-window -t Default -n MDAD -c "$HOME/git/matrix-docker-ansible-deploy"

  # 4. Matrix (mosh)
  tmux new-window -t Default -n Matrix -c "$HOME"
  tmux send-keys -t Default:Matrix 'mssh root@matrix-cloudhub-1.cloudhub.social' Enter

  tmux select-window -t Default:General
}
[[ "$TERM_PROGRAM" != "vscode" ]] && _create_default_tmux_session

# -- Claude tmux session -------------------------------------------------------
# Auto-create the "claude" session with three remote-enabled Claude CLI windows.
# Runs on every non-vscode shell that starts outside tmux; the has-session guard
# makes it a no-op once the session exists.
_create_claude_tmux_session() {
  # Skip in VS Code terminals and when already inside tmux
  [[ "$TERM_PROGRAM" == "vscode" ]] && return
  [[ -n "$TMUX" ]] && return
  command -v tmux   >/dev/null 2>&1 || return
  command -v claude >/dev/null 2>&1 || return

  # Nothing to do if the session already exists
  tmux has-session -t claude 2>/dev/null && return

  # 1. General
  tmux new-session -d -s claude -n General -c "$HOME"
  tmux send-keys -t claude:General 'claude --remote-control General' Enter

  # 2. Charm
  tmux new-window -t claude -n Charm -c "$HOME/git/Charm"
  tmux send-keys -t claude:Charm 'claude --remote-control Charm' Enter

  # 3. MDAD
  tmux new-window -t claude -n MDAD -c "$HOME/git/matrix-docker-ansible-deploy"
  tmux send-keys -t claude:MDAD 'claude --remote-control MDAD' Enter

  # 4. Knowledge-Platform
  tmux new-window -t claude -n Knowledge-Platform -c "$HOME/git/Knowledge-Platform"
  tmux send-keys -t claude:Knowledge-Platform 'claude --remote-control Knowledge-Platform' Enter

  tmux select-window -t claude:Charm
}
[[ "$TERM_PROGRAM" != "vscode" ]] && _create_claude_tmux_session

# VS Code shell integration — must be sourced LAST, after p10k, so its precmd/preexec
# hooks are appended on top of p10k's and not overwritten by it.
[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"

# --- mssh / mosh auto-connect (added by mosh-setup) ---
_mssh_get_host() {
  local skip_next=false
  for arg in "$@"; do
    if $skip_next; then skip_next=false; continue; fi
    case "$arg" in
      -[bcDEeFiIJlLmopQRSw]) skip_next=true ;;
      -*) ;;
      *)  printf '%s' "${arg##*@}"; return ;;
    esac
  done
}

mssh() {
  # Drop-in ssh wrapper: uses mosh for registered hosts, with optional tmux.
  local host hosts_file line tmux_session=""
  host="$(_mssh_get_host "$@")"
  hosts_file="${MOSH_HOSTS_FILE:-${HOME}/.mosh_hosts}"

  if [[ -n "$host" && -f "$hosts_file" ]]; then
    line="$(grep -m1 "^${host}" "$hosts_file" 2>/dev/null || true)"
    if [[ -n "$line" ]]; then
      tmux_session="$(printf '%s' "$line" | awk '{print $2}')"
      if [[ -n "$tmux_session" ]]; then
        echo "[mssh] mosh → ${host} (tmux: ${tmux_session})" >&2
        mosh "$@" -- tmux new-session -A -s "$tmux_session"
      else
        echo "[mssh] mosh → ${host}" >&2
        mosh "$@"
      fi
      return
    fi
  fi

  ssh "$@"
}
# --- end mssh ---

# Added by LM Studio CLI (lms)
export PATH="$PATH:/Users/evie/.lmstudio/bin"
# End of LM Studio CLI section

# tmuxinator
export PATH="$PATH:/opt/homebrew/lib/ruby/gems/4.0.0/bin"
source /opt/homebrew/lib/ruby/gems/4.0.0/gems/tmuxinator-3.4.0/completion/tmuxinator.zsh
