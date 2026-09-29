# chezmoi pilot: one fish setup on the Mac and two Raspberry Pis

## Overview
- Move the cross-platform part of the dotfiles (fish, starship, git, the Brewfile) from dotbot to chezmoi, and use it to give pi-alpha and pi-bravo the same fish, aliases and CLI tools as the MBP.
- Problem: `dotfiles/fish/config.fish` in the working tree guards every alias with `type -q` and wraps Mac-only lines in `if test (uname) = Darwin`. Pavel rejected that split. pi-alpha runs a hand-copied config from 2026-09-12 that already drifted; pi-bravo has no fish at all.
- Design rule of this plan: differences between the OSes live in separate files that are installed on one OS only. Shared files carry no OS or tool-presence conditions.
- Tools come from Homebrew on both OSes. Homebrew 5.0 made Linux ARM64 Tier 1 (needs glibc >= 2.39); both Pis run Debian 13 with glibc 2.41.
- dotbot keeps everything outside the pilot scope. Both tools run side by side on disjoint targets until a later decision to move the rest.

**Hosts in scope:** the MBP (macOS), pi-alpha (Debian 13 aarch64, login shell `/usr/bin/fish` 4.0.2 from apt today), pi-bravo (Debian 13 aarch64, login shell bash, no fish). The MacBook Air follows the MBP after the pilot (Post-Completion).

**Non-goals:**
- no other servers (lasso, launchpad-*, nas) - explicitly out until Pavel asks
- no tmux, yazi, mise config, zsh hack, agterm, claude, Library or LaunchAgent entries in chezmoi - they stay in dotbot
- no mise on Linux; runtimes (node, go, rust, deno, bun, pnpm) stay Mac-only
- no secrets management (1Password templates) - `local.fish` stays machine-local and unmanaged
- no automatic `brew bundle` on the Mac - the Mac keeps `brewup` / `mise run install_tools`
- no removal of apt packages already on pi-alpha (fish, starship, eza, zoxide) - Homebrew's bin simply comes first in PATH

**Rejected alternatives:**
- `type -q` / `uname` guards inside one config.fish - rejected by Pavel, conditions spread across the shared file
- chezmoi templates (`.tmpl`) for OS differences - templates are copied, not symlinked, and are the same conditions in Go syntax; `.chezmoiignore` selects files instead
- apt package lists (mikker's `linux/apt-packages`) - moor, curlie, doggo are missing even on Debian 13; versions differ per distro
- mise or `.chezmoiexternal` binaries for CLI tools - Pavel does not want shell tools in mise; externals need a hand-maintained version per tool
- `chsh` to fish on Linux - `ssh host '<bash>'` one-liners break (documented pain on pi-alpha); bash stays the login shell and execs fish, same as the zsh hack on the Mac
- bare git repo in `$HOME` (bobuk's approach) - keeps OS-specific files out of git entirely

## Skills to invoke

Load each skill below with the Skill tool before the tasks that need it.

- `defuddle` - only if a chezmoi or Homebrew doc page must be read during execution; read docs, do not guess flags

No language skill applies: the plan touches fish, bash, POSIX sh, a Ruby Brewfile and TOML. Follow the repo conventions instead: English everywhere, ASCII hyphens only, keep existing comments when moving lines (they carry the why), no new comments that restate code.

## Context (from discovery)
- dotbot map: `dotfiles/install.conf.yaml` links 290 files; pilot entries are `~/.gitignore_global`, `~/.gitconfig`, `~/.Brewfile`, `~/.config/starship.toml`, `~/.config/fish/config.fish`, `~/.config/fish/fish_plugins`, `~/.config/fish/functions/`.
- dotbot 1.23.1 via `.mise.toml` task `link_dotfiles`; `install_tools` runs `brew bundle install` in `dotfiles/`.
- `dotfiles/Brewfile` (148 entries) loads `brewfiles/<LocalHostName>.rb` via `scutil`, which does not exist on Linux.
- `dotfiles/.gitconfig` hardcodes `excludesfile = /Users/pavel.karpovich/.gitignore_global`, signs commits with `~/.ssh/keys/github-signing`, uses `smerge` as mergetool.
- `dotfiles/fish/functions/starship_narrow.fish` points at `~/Projects/environment/dotfiles/starship-narrow.toml`, a repo path that does not exist on the Pis.
- fisher installs plugin files into `~/.config/fish/functions/` and `conf.d/`, so those directories cannot become directory symlinks into the repo; per-file symlinks as today.
- Mac-only functions (by their calls): brewup, envup (mas, brewup), ccm, wt (agtermctl), zw (open), gm (pbcopy), stable-to-master (defaults), wins (yashiki). skills-restore calls brew; check it during Task 5.
- **Precondition:** the working tree has uncommitted edits in `dotfiles/Brewfile` and `dotfiles/fish/config.fish` (among others). They are Pavel's; they must survive this work. Ask Pavel to commit or confirm them before Task 1 starts, and never `git checkout` those files.

## Development Approach
- **testing approach**: Regular - each task changes config, then extends the verification scripts, then runs them
- "tests" here are two scripts that check the resulting machine state; there is no unit-test framework in this repo
- complete each task fully before moving to the next; small, focused changes
- **every task adds or updates checks** in the verification scripts for what it changed, both the success state and one failure case (a file that must NOT be present on the other OS)
- **all checks must pass before starting the next task**
- **update this plan file when scope changes during implementation**
- nothing is committed or pushed unless Pavel asks

## Testing Strategy
- `scripts/check-home-darwin.sh` - runs on the Mac against the live `$HOME`: `chezmoi verify` clean, pilot targets are symlinks into the repo, `fish --no-execute` passes for every fish file in the chezmoi source, a fish login shell has the expected aliases and none of the Linux-only files exist.
- `scripts/check-home-linux.sh` - runs inside a throwaway `debian:13` arm64 container on the Mac's Colima (Colima runs through launchd; do not start it from a shell) with the repo mounted read-only: full bootstrap from zero, then the same class of assertions for Linux (aliases resolve to Homebrew binaries, Mac-only functions and files absent, `bash -ic` lands in fish, `bash -c 'echo $0'` stays bash).
- Brewfile regression: capture `brew bundle list --all --file=dotfiles/Brewfile` on the Mac before Task 3 and assert the list is identical after the split.
- The container is the only Linux test target before touching a real Pi. Real hosts are verified manually in Post-Completion steps that the executor performs over ssh, one host at a time.

## Progress Tracking
- mark completed items with `[x]` immediately when done
- add newly discovered tasks with ➕ prefix
- document issues/blockers with ⚠️ prefix
- update plan if implementation deviates from original scope

## Solution Overview
- chezmoi source lives inside this repo at `dotfiles/home/`, named by `.chezmoiroot` at the repo root. On the Mac, chezmoi's `sourceDir` is the repo checkout itself; on the Pis `chezmoi init pkarpovich/environment` clones the public repo into chezmoi's default source dir.
- `mode = "symlink"`: every plain file becomes a symlink into the source, so edits in `$HOME` land in git as they do with dotbot. Nothing in the pilot is a template, executable or private, so nothing is copied. `.chezmoi.toml.tmpl` at the source root writes this config on `chezmoi init`.
- OS selection happens in exactly one place: `dotfiles/home/.chezmoiignore` (a template) lists the Linux-only targets under `ne .chezmoi.os "linux"` and the Mac-only targets under `ne .chezmoi.os "darwin"`.
- fish: `config.fish` is shared and unconditional. `conf.d/darwin.fish` and `conf.d/linux.fish` hold per-OS lines; fish sources `conf.d/*` before `config.fish`, which is why brew's shellenv and PATH setup go there.
- git: `.gitconfig` is shared and ends with `[include] path = ~/.gitconfig.darwin`. `~/.gitconfig.darwin` (signing, smerge) is installed on the Mac only. git ignores a missing include file, so Linux needs no counterpart and no template.
- Brewfile: shared part lists what the shared fish config needs; `brewfiles/macos.rb` and `brewfiles/linux.rb` are loaded by `OS.mac?` / `OS.linux?`; host files keep working with a hostname lookup that works on both OSes.
- Linux bootstrap runs from chezmoi scripts: a Linux-only `run_once_before_` script installs Homebrew prerequisites and Homebrew, a `run_onchange_after_` script runs `brew bundle` when the Brewfile set changes, another runs fisher when `fish_plugins` changes, and a `run_once_after_` script adds one sourcing line to `~/.bashrc`.

## Technical Details

**Source layout** (repo-relative):
- `.chezmoiroot` - one line: `dotfiles/home`
- `dotfiles/home/.chezmoi.toml.tmpl` - sets `mode = "symlink"` and `sourceDir` to `{{ .chezmoi.sourceDir }}` so the Mac keeps pointing at the repo
- `dotfiles/home/.chezmoiignore` - OS selection; also ignores `brewfiles` (a source directory next to the Brewfile that must not be installed into `$HOME`)
- `dotfiles/home/dot_gitconfig`, `dot_gitconfig.darwin`, `dot_gitignore_global`
- `dotfiles/home/dot_Brewfile`, `dotfiles/home/brewfiles/{macos,linux,Pavels-MacBook-Air,Pavels-MacBook-Pro-2021}.rb`
- `dotfiles/home/dot_config/starship.toml`, `dot_config/starship-narrow.toml`
- `dotfiles/home/dot_config/fish/{config.fish,fish_plugins}`, `conf.d/{darwin,linux}.fish`, `functions/*.fish`
- `dotfiles/home/dot_config/bash/exec-fish.bash` (Linux only)
- `dotfiles/home/.chezmoiscripts/linux/` - the Linux bootstrap scripts (`.chezmoiscripts` keeps them out of the target tree)

Moves use `git mv` so history follows the files.

**What goes where in fish:**
- shared `config.fish`: LANG, DO_NOT_TRACK, `~/.local/bin` in PATH, local.fish sourcing, EDITOR fallback chain removed (EDITOR moves per OS), all aliases that shadow system commands (cd, ls/la/ll/l/tree, cat, curl, ping, dig, htop), lg, qq, cls, cc/ccr/ccw/ccwr, key binds, zoxide/atuin/starship init, the agterm integration line guarded by file existence as today (it is agterm's own installer block)
- `conf.d/darwin.fish`: `EDITOR "zed --wait"`, GOROOT and `mise activate` with its completions, mise shims and `~/.dotnet/tools` PATH, libpq PATH, pnpm aliases (pui, pu), rx/rxw (keep `--skip-finalize` from the working tree), f, cb, gg, e
- `conf.d/linux.fish`: Homebrew shellenv for `/home/linuxbrew/.linuxbrew`, `EDITOR vim`
- shadowing aliases are safe without guards only because the Brewfile guarantees their tools on both OSes; plain aliases for tools that may be absent (cc, lg) need no guard because an alias only fails when invoked

**Linux shell entry:** `~/.config/bash/exec-fish.bash` mirrors `dotfiles/zsh/zshrc`: exec `fish -l` from Homebrew's prefix with `SHELL` set, only when the shell is interactive, stdin and stdout are ttys, it is not `bash -c`, and `BASH_STAY` is unset. The bootstrap appends one line to `~/.bashrc` that sources it if present, idempotently (grep before append). Debian's default `.bashrc` returns early for non-interactive shells and `~/.profile` sources `.bashrc`, so ssh logins reach the hook and `ssh host 'cmd'` does not.

**Homebrew on Linux:** prerequisites `build-essential procps curl file git` via `sudo apt-get install -y`; installer run with `NONINTERACTIVE=1`; prefix `/home/linuxbrew/.linuxbrew`. The before-script skips everything when `brew` already exists.

**Brewfile split:** the shared list is exactly: fish, git, starship, atuin, zoxide, eza, moor, curlie, gping, doggo, glances, lazygit, chezmoi, plus anything `functions/` that stay shared call. Everything else moves to `brewfiles/macos.rb` unchanged and in the same groups. Casks, `mas` entries and taps used only by Mac formulae live in `macos.rb`. Host files load after the OS file.

## What Goes Where
- **Implementation Steps**: repo changes and the container test, all doable from the Mac
- **Post-Completion**: switching the live Mac from dotbot to chezmoi for the pilot targets and rolling out to pi-alpha and pi-bravo over ssh - each is a live-machine change Pavel should see happen

## Implementation Steps

Deviations found during implementation (the plan text below is kept as written):
- ➕ chezmoi v2.73.0 (Homebrew).
- ➕ One naming scheme everywhere: `darwin` / `linux`. The Brewfile loads `brewfiles/#{OS.kernel_name.downcase}.rb`, so the Mac file is `darwin.rb` (not `macos.rb`) and there is no OS conditional in the Brewfile at all; `linux.rb` does not exist yet and is optional.
- ➕ The host-file loader (`scutil --get LocalHostName`) moved to the end of `darwin.rb`: host files are Mac hosts, so no cross-OS hostname lookup is needed.
- ➕ `git` stays Mac-only in the Brewfile (its comment is about shadowing Apple's git); Linux uses the distro git that the Homebrew installer already requires.
- ➕ Shared functions: brewup, envup, claude, gdub, starship_narrow, starship_normal. brewup/envup work on Linux because Homebrew is there; claude passes straight through outside agterm. Everything else is in the Linux section of `.chezmoiignore`, fish_greeting included (it runs yafetch); `conf.d/linux.fish` blanks `fish_greeting` instead.
- ➕ The agterm agent-status block stays in the shared `config.fish` with its `test -f` guard: agterm's installer looks for the block in `~/.config/fish/config.fish` specifically (string in the agterm binary) and would re-add it anywhere else.
- ➕ Linux scripts sit flat in `.chezmoiscripts/` with a `linux-` name prefix and render empty on macOS, which makes chezmoi skip them.
- ➕ `link_dotfiles` in `.mise.toml` now also runs `chezmoi --source "$PWD" init --apply`.
- ➕ fisher comes from Homebrew on Linux (`brewfiles/linux.rb`): the first container run fetched fisher.fish from raw.githubusercontent.com and got a one-off 403, which aborted the bootstrap. The fisher script now only runs `fisher update`.
- ➕ The tty checks in `check-home-linux.sh` look at the process `script` ends up running instead of feeding it input: fish 4 waits 10 s for a Primary Device Attributes reply that `script`'s pty never sends, so typed input never ran.
- ➕ Result: `scripts/check-home-darwin.sh` all green on the MBP, `scripts/check-home-linux.sh` 34/34 in debian:13 arm64.
- ⚠️ Running dotbot during verification replaced the real `~/Library/Application Support/Claude/claude_desktop_config.json` (Claude Desktop had turned the symlink into a file) with the repo symlink, because the map uses `force: true`. Unrelated to this plan's files, but a known dotbot hazard for app-owned configs.
- ⚠️ Two dangling links in `~/.config/fish/functions/` (`__ccz_close_tab.fish`, `agent-browser-skill-sync.fish`) are dotbot leftovers of functions deleted in 1c29069 and earlier; chezmoi does not manage them.

### Task 1: chezmoi skeleton in the repo

**Files:**
- Create: `.chezmoiroot`
- Create: `dotfiles/home/.chezmoi.toml.tmpl`
- Create: `dotfiles/home/.chezmoiignore`
- Create: `scripts/check-home-darwin.sh`
- Modify: `dotfiles/Brewfile` (add `chezmoi` to the shell group)

- [x] install chezmoi with brew and record the version in this plan
- [x] create the root marker and config template (`mode = "symlink"`, `sourceDir`); verify with `chezmoi init --source <repo> --dry-run`-style inspection that the generated config is what Technical Details says, reading chezmoi docs rather than guessing flags
- [x] create `.chezmoiignore` with both OS sections (empty lists for now) and `brewfiles`
- [x] write `scripts/check-home-darwin.sh` with the first checks: chezmoi config has symlink mode and the repo as source, `chezmoi managed` lists nothing yet
- [x] add a failure-case check: the script exits non-zero when run with a config that lacks symlink mode
- [x] run the script - must pass before Task 2

### Task 2: git config into chezmoi

**Files:**
- Move: `dotfiles/.gitconfig` -> `dotfiles/home/dot_gitconfig`
- Move: `dotfiles/.gitignore_global` -> `dotfiles/home/dot_gitignore_global`
- Create: `dotfiles/home/dot_gitconfig.darwin`
- Modify: `dotfiles/home/.chezmoiignore`
- Modify: `dotfiles/install.conf.yaml`
- Modify: `scripts/check-home-darwin.sh`

- [x] move both files with `git mv`; replace the absolute excludesfile path with `~/.gitignore_global`
- [x] move `signingkey`, `[gpg]`, `[commit] gpgsign`, `[merge] tool` and `[mergetool "smerge"]` into `dot_gitconfig.darwin`; add the include line to `dot_gitconfig`; ignore `.gitconfig.darwin` on Linux
- [x] remove the two git entries from `install.conf.yaml`
- [x] extend the check script: `git config --get commit.gpgsign` is true on the Mac through the include, `core.excludesfile` resolves to an existing file
- [x] failure case: with `HOME` pointing at a temp dir holding only `.gitconfig`, `git config --get commit.gpgsign` is empty and git does not error
- [x] run the script - must pass before Task 3

### Task 3: Brewfile split by OS

**Files:**
- Move: `dotfiles/Brewfile` -> `dotfiles/home/dot_Brewfile`
- Move: `dotfiles/brewfiles/*.rb` -> `dotfiles/home/brewfiles/`
- Create: `dotfiles/home/brewfiles/macos.rb`, `dotfiles/home/brewfiles/linux.rb`
- Modify: `.mise.toml` (`install_tools` path), `dotfiles/install.conf.yaml` (drop `~/.Brewfile`), `dotfiles/README.md`, `README.md`
- Modify: `scripts/check-home-darwin.sh`

- [x] before any edit, save `brew bundle list --all --file=dotfiles/Brewfile` output into the check script's fixture (committed as `scripts/fixtures/brewfile-darwin.txt`)
- [x] move files with `git mv`, keeping the working-tree edits of the Brewfile
- [x] split per Technical Details; replace the `scutil` host lookup with one that works on both OSes; `linux.rb` starts empty apart from anything Linux-only that the shared list cannot carry
- [x] update every reference to the old Brewfile path (grep the repo for `dotfiles/Brewfile` and `brewfiles/`)
- [x] check: `brew bundle list --all --file=dotfiles/home/dot_Brewfile` on the Mac equals the fixture
- [x] failure case: evaluating the Brewfile with `OS.mac?` false (a Linux container in Task 7 covers the real run; here, a Ruby one-liner that loads it under a stubbed OS) lists no casks or mas entries
- [x] run the script - must pass before Task 4

### Task 4: starship into chezmoi

**Files:**
- Move: `dotfiles/starship.toml` -> `dotfiles/home/dot_config/starship.toml`
- Move: `dotfiles/starship-narrow.toml` -> `dotfiles/home/dot_config/starship-narrow.toml`
- Modify: `dotfiles/fish/functions/starship_narrow.fish` (point at `~/.config/starship-narrow.toml`)
- Modify: `dotfiles/install.conf.yaml`, any repo references found by grep
- Modify: `scripts/check-home-darwin.sh`

- [x] move and repoint as listed
- [x] check: both starship files are symlinks into the repo after apply; `starship_narrow` sets a path that exists
- [x] failure case: the old repo-path string no longer appears anywhere in `dotfiles/`
- [x] run the script - must pass before Task 5

### Task 5: fish config split into shared and per-OS files

**Files:**
- Move: `dotfiles/fish/config.fish`, `dotfiles/fish/fish_plugins`, `dotfiles/fish/functions/*.fish` -> `dotfiles/home/dot_config/fish/`
- Create: `dotfiles/home/dot_config/fish/conf.d/darwin.fish`, `dotfiles/home/dot_config/fish/conf.d/linux.fish`
- Modify: `dotfiles/home/.chezmoiignore`, `dotfiles/install.conf.yaml`, `dotfiles/README.md`, `dotfiles/agterm/README.md` and any other file grep finds referencing `dotfiles/fish/`
- Modify: `scripts/check-home-darwin.sh`

- [x] start from the working-tree `config.fish` (it carries Pavel's uncommitted edits such as `--skip-finalize`); move with `git mv`
- [x] redistribute lines per "What goes where in fish"; remove every `type -q` guard and the `uname` block; the shared file ends up with no OS or tool-presence condition except the agterm integration line
- [x] classify functions: the Mac-only list from Context plus anything else calling brew/open/pbcopy/agtermctl/defaults/osascript; confirm skills-restore; list them under the Linux section of `.chezmoiignore`, and `conf.d/darwin.fish` there too; `conf.d/linux.fish` goes under the macOS section
- [x] remove the three fish entries from `install.conf.yaml`; update references to the old paths
- [x] check: `fish --no-execute` on every fish file in the source; a `fish -l -c` run on the Mac shows `ls` aliased to eza, `rx` defined, EDITOR is zed
- [x] failure case: `conf.d/linux.fish` is not present in `~/.config/fish/conf.d` on the Mac; `grep -E 'type -q|uname'` on the shared config.fish finds nothing
- [x] run the script - must pass before Task 6

### Task 6: Linux bootstrap scripts and bash entry

**Files:**
- Create: `dotfiles/home/dot_config/bash/exec-fish.bash`
- Create: `dotfiles/home/.chezmoiscripts/linux/run_once_before_10-homebrew.sh.tmpl`
- Create: `dotfiles/home/.chezmoiscripts/linux/run_onchange_after_20-brew-bundle.sh.tmpl`
- Create: `dotfiles/home/.chezmoiscripts/linux/run_onchange_after_30-fisher.sh.tmpl`
- Create: `dotfiles/home/.chezmoiscripts/linux/run_once_after_40-bashrc.sh.tmpl`
- Modify: `dotfiles/home/.chezmoiignore`

- [x] each script is a template only to exit on non-Linux and to embed the hash it reacts to (`include` + `sha256sum` of the Brewfile set for bundle, of `fish_plugins` for fisher); bodies are plain POSIX sh
- [x] homebrew script: skip when `brew` exists; otherwise apt prerequisites, then the official installer non-interactively
- [x] brew-bundle script: `brew bundle --file ~/.Brewfile`; fisher script: install fisher if missing, then `fisher update`, run through Homebrew's fish
- [x] bashrc script: append the sourcing line only if absent; `exec-fish.bash` follows "Linux shell entry"
- [x] ignore `.config/bash` on the Mac
- [x] syntax checks: `sh -n` on rendered scripts (render with `chezmoi execute-template`), `bash -n` on `exec-fish.bash`
- [x] run `scripts/check-home-darwin.sh` - still passes, and no Linux script runs on the Mac (`chezmoi apply --dry-run -v` shows none)

### Task 7: Linux container test

**Files:**
- Create: `scripts/check-home-linux.sh`

- [x] the script starts `debian:13` (arm64) with the repo mounted read-only, creates a sudo-enabled non-root user, installs chezmoi into `~/.local/bin`, and runs `chezmoi init --apply` with the mounted repo as source
- [x] assertions inside the container: pilot targets are symlinks into the source; `fish -l -c 'type ls'` resolves to eza from `/home/linuxbrew`; `brewup`, `wt`, `conf.d/darwin.fish`, `.gitconfig.darwin` are absent; `bash -ic 'echo $SHELL'` reports fish; `bash -c 'echo ok'` stays bash; `BASH_STAY=1 bash -i` stays bash; `git config --get commit.gpgsign` is empty
- [x] idempotency: a second `chezmoi apply` makes no changes and runs no scripts; the `.bashrc` line appears once
- [x] the script tears the container down on exit, success or failure
- [x] run it - must pass before Task 8

### Task 8: Verify acceptance criteria
- [x] shared `config.fish` has no `type -q` and no `uname`
- [x] both check scripts pass; the Brewfile fixture still matches
- [x] `dotfiles/install.conf.yaml` has no pilot entries and `dotbot -c dotfiles/install.conf.yaml` still runs clean on the Mac
- [x] grep the repo for stale paths: `dotfiles/fish/`, `dotfiles/Brewfile`, `dotfiles/starship`, `dotfiles/.gitconfig`

### Task 9: [Final] Update documentation
- [x] `README.md` Setup section: chezmoi for the pilot scope, dotbot for the rest, the one-line Linux bootstrap
- [x] `dotfiles/README.md`: where fish, git, starship and the Brewfile live now and how per-OS files are selected
- [x] move this plan to `docs/plans/completed/`

## Post-Completion
*Live-machine steps, done over ssh one host at a time, each with Pavel watching*

**MBP switch:**
- back up the current pilot targets (they are dotbot symlinks into old repo paths that no longer exist after the moves, so do this right after the moves land), `chezmoi init --source <repo>` then `chezmoi apply`, run `scripts/check-home-darwin.sh`
- open a new agterm session and check the prompt, aliases and `rx`

**pi-alpha:**
- back up `~/.config/fish` to `~/.config/fish.bak-<date>`, then remove the copied files
- `sudo chsh -s /bin/bash "$USER"` (the login shell goes back to bash; the hook brings fish)
- chezmoi bootstrap: `sh -c "$(curl -fsLS get.chezmoi.io)" -- -b ~/.local/bin init --apply pkarpovich/environment` - this needs the pilot pushed to GitHub first, which is Pavel's call
- verify a fresh ssh login lands in Homebrew's fish, `ssh pi-alpha 'echo $0'` answers from bash
- update `docs/alpha-host.md` in home-environment: the note that `pi`'s shell is fish and bash one-liners break no longer holds

**pi-bravo:** same bootstrap; the login shell is already bash

**Later, separate decisions:**
- the MacBook Air: same as the MBP
- moving the rest of dotbot's map to chezmoi, or leaving it
- other servers
