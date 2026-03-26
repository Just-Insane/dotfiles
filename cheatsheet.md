# Cheatsheet

- [Shell](#shell)
- [tmux](#tmux)
- [Doom Emacs](#doom-emacs)

---

## Shell

### Aliased Commands (modern replacements)

| Type | Old → New | Command | Bypass |
|------|-----------|---------|--------|
| pager | `cat` → `bat` | `bat --style=plain --pager=never` | `\cat` |
| ls | `ls` → `eza` | `eza` | `\ls` |
| find | `find` → `fd` | `fd` | `\find` ⚠️ different syntax |
| grep | `grep` → `rg` | `rg --smart-case` | `\grep` |
| curl | `curl` → `xh` | `xh --follow --timeout=30` | `\curl` |
| cp | `cp` → `rsync` | `rsync -ah --progress` | `\cp` |
| du | `du` → `dust` | `dust --reverse` | `\du` |
| df | `df` → `duf` | `duf` | `\df` |
| diff | `diff` → `delta` | `delta` | `\diff` |
| top | `top` → `btop` | `btop` | `\top` |
| cd | `cd` → `zoxide` | `zoxide init zsh --cmd cd` | `builtin cd` |
| help | `man` supplement | `tldr <cmd>` | — |

> All replacements are guarded with `command -v` so they're no-ops if the tool isn't installed.
> Disabled in VS Code terminal: `bat`, `eza` (icon rendering issues).

---

## eza listing aliases

| Alias | Command | Purpose |
|-------|---------|---------|
| `ls` | `eza` | simple listing |
| `ll` | `eza -la --icons --git --group-directories-first --time-style=long-iso` | long, all files, git status |
| `la` | same as `ll` | long, all files |
| `lt` | `eza --tree --icons --git-ignore` | tree view, respects .gitignore |

---

## bat config

```
BAT_THEME=Solarized (dark)
MANPAGER → bat (man pages with syntax highlighting)
```

---

## xh (curl replacement)

```sh
xh get httpbin.org/get        # GET request
xh post api.example.com/ep key=value   # POST with JSON body (auto-detected)
xh -d file.json post api.example.com   # POST from file
```

- `XH_HTTPS=true` — bare hostnames default to https
- `--follow` — follows redirects (set by alias)
- `--timeout=30` — fails fast (set by alias)

---

## fd (find replacement)

```sh
fd pattern                    # find files matching pattern
fd pattern src/               # scoped to directory
fd -e ts                      # by extension
fd -H pattern                 # include hidden files
fd --type d pattern           # directories only
\find . -name pattern         # bypass to real find
```

---

## rg (grep replacement)

```sh
rg pattern                    # search current dir recursively
rg pattern src/               # scoped
rg -l pattern                 # filenames only
rg -t ts pattern              # filter by filetype
rg --no-ignore pattern        # include .gitignored files
```

---

## delta (diff replacement)

```sh
delta file1 file2             # diff two files
git diff | delta              # pipe git diff through delta
diff file1 file2 | delta      # pipe unified diff
```

Delta is also wired as the git pager (`core.pager = delta`).

---

## Git aliases & config

| Alias | Expands to |
|-------|-----------|
| `gwl` | `git worktree list` |
| `gwa` | `git worktree add` |
| `gwr` | `git worktree remove` |
| `lg` | `lazygit` |

**gitconfig additions:**

```ini
[delta]
    line-numbers = true
    navigate = true        # n/N to jump between diff hunks
    side-by-side = true
[merge]
    conflictstyle = zdiff3 # better 3-way conflict markers
[rebase]
    autosquash = true      # auto-apply fixup!/squash! commits
[push]
    autoSetupRemote = true # no more --set-upstream
[fetch]
    prune = true           # auto-delete stale remote tracking branches
```

---

## GitHub CLI aliases

| Alias | Command |
|-------|---------|
| `prl` | `gh pr list` |
| `prv` | `gh pr view --web` |
| `prc` | `gh pr create` |
| `ghr` | `gh repo view --web` |

---

## Misc aliases

| Alias | Expands to |
|-------|-----------|
| `k` | `k9s` (Kubernetes TUI) |
| `help` | `tldr` (practical examples) |
| `powershell` | `pwsh` |
| `mkcd dir` | `mkdir -p dir && cd dir` |

---

## zoxide (smart cd)

```sh
cd projects           # jumps to best match for "projects"
cd proj foo           # narrows by multiple terms
zi                    # interactive fuzzy picker (fzf)
z -                   # go back to previous directory
```

Learns from your `cd` history. First visit still uses normal cd.

---

## fzf keybindings

| Key | Action |
|-----|--------|
| `Ctrl+T` | fuzzy-insert file path at cursor |
| `Ctrl+R` | fuzzy search shell history |
| `Alt+C` | fuzzy cd into subdirectory |

Uses `fd` as the backend (respects `.gitignore`, finds hidden files).

---

## Pending setup actions

```sh
source ~/.zshrc                        # activate all alias changes
rm ~/.cache/zoxide-init.zsh            # one-time: activate cd → zoxide
doom sync                              # install: magit-delta, vertico, org-ql, eat, vulpea
# In tmux: <prefix>+I                  # install tmux-fzf and tmux-fingers
```

---

## tmux

Framework: [gpakosz/.tmux](https://github.com/gpakosz/.tmux). Config: `~/.tmux.conf.local`.
Default prefix: `C-b` (also `C-a` as prefix2).

### Session / window / pane

| Key | Action |
|-----|--------|
| `<prefix> c` | new window (retains current path) |
| `<prefix> -` | split pane horizontally |
| `<prefix> _` | split pane full-width horizontally |
| `<prefix> \|` | split pane vertically |
| `<prefix> h/j/k/l` | navigate panes (vim-style) |
| `<prefix> H/J/K/L` | resize pane |
| `<prefix> z` | zoom/unzoom pane |
| `<prefix> q` | show pane numbers (hit number to jump) |
| `<prefix> x` | kill pane |
| `<prefix> &` | kill window |
| `<prefix> $` | rename session |
| `<prefix> ,` | rename window |
| `<prefix> s` | choose session (tree view) |
| `<prefix> w` | choose window |

### Copy mode

| Key | Action |
|-----|--------|
| `<prefix> [` | enter copy mode |
| `v` | begin selection (vi mode) |
| `y` | copy selection → OS clipboard |
| `<prefix> ]` | paste |

Copy-to-OS-clipboard is enabled (`tmux_conf_copy_to_os_clipboard=true`).

### Config management

| Key | Action |
|-----|--------|
| `<prefix> e` | edit `~/.tmux.conf.local` |
| `<prefix> r` | reload config |
| `<prefix> m` | toggle mouse mode |

### Plugins

| Plugin | Key | Action |
|--------|-----|--------|
| **tmux-resurrect** | `<prefix> Ctrl+s` | save session to disk |
| | `<prefix> Ctrl+r` | restore saved session |
| **tmux-continuum** | *(automatic)* | auto-saves every 15 min; restores on start |
| **tmux-fzf** | `<prefix> F` | fuzzy switch: sessions, windows, panes, commands, processes |
| **tmux-fingers** | `<prefix> y` | highlight copyable strings (URLs, paths, git hashes, IPs) |

Install plugins: `<prefix> I` &nbsp; · &nbsp; Update: `<prefix> u` &nbsp; · &nbsp; Uninstall: `<prefix> Alt+u`

### Custom config (`.tmux.conf.local`)

```
history-limit = 50000
display-panes-time = 2000ms   (prefix+q pane numbers stay longer)
mouse = on
new-window/pane retains current path
SSH reconnect on new pane = true
```

---

## Doom Emacs

Config lives in `~/.doom.d/config.org` (literate — tangles to `config.el`, `packages.el`, `init.el`).
**Edit `config.org` only** — save to auto-tangle. Run `doom sync` after adding packages.

### Packages added this session

| Package | Purpose | Notes |
|---------|---------|-------|
| `vertico` (+icons) | Completion UI — replaces ivy | enabled via `init.el` |
| `vulpea` | org-roam utilities, agenda category display | |
| `org-ql` | structured query language for org files | `M-x org-ql-search`, `org-ql-view` |
| `eat` | fast terminal emulator (eshell integration) | auto-hooks into eshell-mode |
| `magit-delta` | delta-powered diffs in Magit | auto-enabled via `magit-delta-mode` |
| `auto-dark` | auto light/dark theme based on macOS setting | themes: doom-one / doom-one-light |

### Key bindings (Evil / SPC leader)

| Key | Action |
|-----|--------|
| `SPC .` | find file |
| `SPC ,` | switch buffer |
| `SPC b k` | kill buffer |
| `SPC f s` | save file |
| `SPC g g` | Magit status |
| `SPC g b` | Magit blame |
| `SPC o t` | open vterm |
| `SPC o e` | open eshell (eat hooks in here) |
| `SPC s r` | search ripgrep project |
| `SPC n r f` | org-roam find node |
| `SPC n r i` | org-roam insert node |
| `SPC n r g` | org-roam graph (opens org-roam-ui in browser) |
| `SPC o a` | org-agenda |
| `SPC m t` | org set todo state |
| `SPC m s` | org schedule |
| `SPC m d` | org deadline |
| `g z` | fold/unfold |
| `SPC h r r` | reload Doom config |

### org-ql queries

```elisp
M-x org-ql-search       ;; interactive search with query builder
M-x org-ql-view         ;; named saved views

;; Example queries:
(todo "TODO")
(and (todo "TODO") (deadline :to today))
(tags "project" "active")
(heading "meeting")
```

### Magit + delta

Delta provides syntax-highlighted diffs in Magit buffers.
- `n`/`N` in diff view: jump between hunks
- `TAB`: expand/collapse sections
- `s`/`u`: stage/unstage hunk at point
- `c c`: commit

### eat terminal

Activated automatically in eshell via `eat-eshell-mode` hook.
- Full terminal emulation inside eshell
- `C-c C-k`: kill running process
- Use `M-x eat` to open a standalone eat terminal buffer

### doom sync reminder

```sh
doom sync          # after changing packages or init.el
doom upgrade       # upgrade Doom + all packages
doom doctor        # diagnose config issues
doom build         # recompile packages (after native comp issues)
```

