# `alleyuup` & `dots` — Shared Tools Gist

This private Gist (`alleyuup-repo`) holds the canonical, machine-independent **`alleyuup`** (local upgrade script) and **`dots`** (per-machine config Gist manager).

Per-machine configs, `Brewfile`, and local `alleyuup` overrides (`alleyuup.conf` -> `~/.config/alleyuup/config`) live in each machine's own private Gist (for example, `example-machine-gist`).

---

## One-Line Install on Any Machine

```sh
curl -fsSL https://gist.githubusercontent.com/ryanpcmcquen/alleyuup-repo/raw/install.sh | bash
```

Then to connect a machine's config Gist:
```sh
dots repo   # Enter existing machine Gist ID, path, or 'new'
dots link   # Symlinks all machine configs
```

> **Switching from `alleyup` -> `alleyuup`**: On machines that had the older `alleyup` installed, remove the old symlink/config dir and re-run the installer:
> ```sh
> rm -rf ~/bin/alleyup ~/.config/alleyup
> curl -fsSL https://gist.githubusercontent.com/ryanpcmcquen/alleyuup-repo/raw/install.sh | bash
> ```

---

## Customizing `alleyuup` Per Machine (`~/.config/alleyuup/config`)

If a package or upgrade step is misbehaving on a specific machine, you don't need to fork `alleyuup`. Edit that machine's config:

```sh
alleyuup --config   # Opens ~/.config/alleyuup/config in $EDITOR
```

Because `~/.config/alleyuup/config` is symlinked to `alleyuup.conf` in that machine's `dots` Gist, your overrides are tracked per-machine:

- **Disable any step** by setting its toggle to `0`:
  ```sh
  ALLEYUUP_MAS=0        # Skip Mac App Store updates on this machine
  ALLEYUUP_MACOS=0      # Always skip macOS softwareupdate on this machine
  ALLEYUUP_OPENCLAW=0   # Skip OpenClaw updates
  ```
- **Skip broken packages** while upgrading everything else:
  ```sh
  ALLEYUUP_BREW_IGNORE=("some-formula")
  ALLEYUUP_CASK_IGNORE=("some-cask")
  ALLEYUUP_NPM_IGNORE=("some-npm-pkg")
  ```
- **Add custom hooks or override a step completely** with bash functions:
  ```sh
  alleyuup_before() {
    echo "Running custom pre-upgrade tasks..."
  }

  alleyuup_after() {
    echo "Running custom post-upgrade tasks..."
  }
  ```

---

## Commands Reference

### `alleyuup`
```sh
alleyuup                 # Self-update tools Gist, then run all enabled upgrades
alleyuup --fast          # Skip macOS softwareupdate (alias: --no-macos)
alleyuup --dry-run       # Show what would change, without changing anything
alleyuup --only brew,mas # Run only the listed steps
alleyuup --skip npm,uv   # Skip the listed steps
alleyuup --no-self-update# Skip pulling latest alleyuup & dots from this Gist
alleyuup --config        # Open ~/.config/alleyuup/config in $EDITOR
alleyuup --init-config   # Create the config with defaults, no editor
alleyuup --print-config  # Print active ~/.config/alleyuup/config
alleyuup --print-steps   # Print resolved step toggles (debugging)
```

Step keys for `--only`/`--skip`:
`self-update brew mas agy claude opencode openclaw nvm npm pnpm rustup uv pipx gh-ext repos flint scribe local-projects brewfile repo-sync shell macos`

Notes:
- Precedence is `defaults < ~/.config/alleyuup/config < environment < CLI flags`, so `ALLEYUUP_BREW=0 alleyuup` works for a one-off run.
- `flint` and `scribe` build independently; `local-projects` is shorthand for both (e.g. `alleyuup --skip scribe`).
- Repository pulls run in parallel, capped by `ALLEYUUP_JOBS` (default `6`), and only repos whose local `HEAD` moved are reported as `updated`.
- The macOS update scan is cached for `ALLEYUUP_MACOS_CHECK_HOURS` (default `24`) so `softwareupdate -l` is not paid on every run. Set it to `0` to always rescan.
- A lock prevents overlapping runs, so two logins can't collide on Homebrew, npm, or the Gist; a lock older than `ALLEYUUP_LOCK_MAX_HOURS` (default `6`) is reclaimed so a hung run can't block future ones.
- Network git operations are capped by `ALLEYUUP_NET_TIMEOUT` (default `180` seconds), with SSH `ConnectTimeout`/keepalives and git HTTP low-speed aborts, so a stalled remote cannot hang the run.
- Set `ALLEYUUP_LOG=1` (or a path) to tee output to `~/Library/Logs/alleyuup.log`; the log is rotated to the last 500 lines once it exceeds 5 MB.
- `ALLEYUUP_NOTIFY=1` posts a macOS notification when a run ends with failed steps (used by the weekly job).
- Tracked paths are checked against a sensitive deny-list (`~/.ssh`, `~/.gnupg`, `gh/hosts.yml`, `opencode/service.json`, …), so credentials cannot be committed by accident.

### `dots`
```sh
dots status             # Show symlink health & git status for both tools and machine Gists
dots diff               # Show uncommitted changes in the machine Gist
dots sync [msg]         # Refresh Brewfile, commit machine config changes, and push
dots pull               # Pull latest changes for both tools and machine Gists & re-link
dots link               # Symlink alleyuup, dots, and all machine config files
dots add <file> [name]  # Track a new config file in the machine Gist
dots clean [keep]       # Prune stale '.bak.<timestamp>' backups (keeps newest 3)
dots doctor             # Health check: links, completions, repo, PATH, schedule
dots restore            # Install Brewfile packages and link everything (brew bootstrap)
dots restore --schedule # Same, plus install the weekly job
dots lint               # bash -n + shellcheck (if installed) + both test suites
dots schedule install   # Weekly launchd run (Sunday 03:00), logs to ~/Library/Logs
dots schedule status    # Show schedule state
dots schedule print     # Print the generated launchd plist (no changes)
dots schedule remove    # Remove the schedule
dots repo [target]      # View or change the machine's config Gist
```

Shell completions for Fish and Zsh are installed by `install.sh` (and re-linked by `dots link`); the Zsh files land in `~/.local/share/zsh/site-functions`, so add that directory to `fpath` in `~/.zshrc` before `compinit`.
