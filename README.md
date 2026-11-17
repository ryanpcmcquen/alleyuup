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
alleyuup --no-self-update# Skip pulling latest alleyuup & dots from this Gist
alleyuup --config        # Open ~/.config/alleyuup/config in $EDITOR
alleyuup --print-config  # Print active ~/.config/alleyuup/config
```

Notes:
- Repository pulls run in parallel, and only repos whose local `HEAD` moved are reported as `updated`.
- The macOS update scan is cached for `ALLEYUUP_MACOS_CHECK_HOURS` (default `24`) so `softwareupdate -l` is not paid on every run. Set it to `0` to always rescan.
- A lock prevents overlapping runs, so two logins can't collide on Homebrew, npm, or the Gist.

### `dots`
```sh
dots status             # Show symlink health & git status for both tools and machine Gists
dots diff               # Show uncommitted changes in the machine Gist
dots sync [msg]         # Refresh Brewfile, commit machine config changes, and push
dots pull               # Pull latest changes for both tools and machine Gists & re-link
dots link               # Symlink alleyuup, dots, and all machine config files
dots add <file> [name]  # Track a new config file in the machine Gist
dots clean [keep]       # Prune stale '.bak.<timestamp>' backups (keeps newest 3)
dots repo [target]      # View or change the machine's config Gist
```
