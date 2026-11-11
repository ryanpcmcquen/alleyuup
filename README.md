# `alleyup` & `dots` — Shared Tools Gist

This private Gist (`alleyuup-repo`) holds the canonical, machine-independent **`alleyup`** (local upgrade script) and **`dots`** (per-machine config Gist manager).

Per-machine configs, `Brewfile`, and local `alleyup` overrides (`alleyup.conf` -> `~/.config/alleyup/config`) live in each machine's own private Gist (for example, `example-machine-gist`).

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

---

## Customizing `alleyup` Per Machine (`~/.config/alleyup/config`)

If a package or upgrade step is misbehaving on a specific machine, you don't need to fork `alleyup`. Edit that machine's config:

```sh
alleyup --config   # Opens ~/.config/alleyup/config in $EDITOR
```

Because `~/.config/alleyup/config` is symlinked to `alleyup.conf` in that machine's `dots` Gist, your overrides are tracked per-machine:

- **Disable any step** by setting its toggle to `0`:
  ```sh
  ALLEYUP_MAS=0        # Skip Mac App Store updates on this machine
  ALLEYUP_MACOS=0      # Always skip macOS softwareupdate on this machine
  ALLEYUP_OPENCLAW=0   # Skip OpenClaw updates
  ```
- **Skip broken packages** while upgrading everything else:
  ```sh
  ALLEYUP_BREW_IGNORE=("some-formula")
  ALLEYUP_CASK_IGNORE=("some-cask")
  ALLEYUP_NPM_IGNORE=("some-npm-pkg")
  ```
- **Add custom hooks or override a step completely** with bash functions:
  ```sh
  alleyup_before() {
    echo "Running custom pre-upgrade tasks..."
  }

  alleyup_after() {
    echo "Running custom post-upgrade tasks..."
  }
  ```

---

## Commands Reference

### `alleyup`
```sh
alleyup                 # Self-update tools Gist, then run all enabled upgrades
alleyup --fast          # Skip macOS softwareupdate (alias: --no-macos)
alleyup --no-self-update# Skip pulling latest alleyup & dots from this Gist
alleyup --config        # Open ~/.config/alleyup/config in $EDITOR
alleyup --print-config  # Print active ~/.config/alleyup/config
```

### `dots`
```sh
dots status             # Show symlink health & git status for both tools and machine Gists
dots diff               # Show uncommitted changes in the machine Gist
dots sync [msg]         # Refresh Brewfile, commit machine config changes, and push
dots pull               # Pull latest changes for both tools and machine Gists & re-link
dots link               # Symlink alleyup, dots, and all machine config files
dots add <file> [name]  # Track a new config file in the machine Gist
dots repo [target]      # View or change the machine's config Gist
```
