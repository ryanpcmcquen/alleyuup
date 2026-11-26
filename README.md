# alleyuup

[![CI](https://github.com/ryanpcmcquen/alleyuup/actions/workflows/ci.yml/badge.svg)](https://github.com/ryanpcmcquen/alleyuup/actions/workflows/ci.yml)

A small, dependency-free macOS upgrade script (`alleyuup`) and a per-machine dotfiles manager (`dots`), designed to be safe to run unattended.

- **`alleyuup`** upgrades Homebrew formulae and casks, Mac App Store apps, standalone CLIs, global language packages, local `~/code` repositories, and macOS point/security updates — skipping major macOS upgrades by default.
- **`dots`** keeps shell/editor configs and a `Brewfile` in a per-machine private Gist (symlinked into `$HOME`), and handles linking, syncing, health checks, and a weekly schedule.

## Requirements

- macOS (Apple Silicon or Intel), Bash 3.2+
- Homebrew (optional; steps are skipped when tools are missing)
- `git`, and `gh` for the `dots repo new` flow

## Install

```sh
curl -fsSL https://raw.githubusercontent.com/ryanpcmcquen/alleyuup/main/install.sh | bash
```

This clones the repo to `~/code/alleyuup` and links `alleyuup`, `dots`, and their Fish/Zsh completions. Then connect this machine's config Gist:

```sh
dots repo    # existing Gist ID/URL, a local path, or 'new'
dots link
```

`dots link` symlinks every tracked config that exists on this machine and seeds an `alleyuup.conf` in the Gist if one is missing.

## Usage

```sh
alleyuup                    # self-update, then run every enabled step
alleyuup --fast             # skip macOS software updates (alias: --no-macos)
alleyuup --dry-run          # show what would change, change nothing
alleyuup --only brew,mas    # run only these steps
alleyuup --skip npm,repos   # run everything except these
alleyuup --config           # edit ~/.config/alleyuup/config
alleyuup --print-steps      # show resolved step toggles
alleyuup --check            # compare the local copy with the repo
```

Step keys: `self-update brew mas agy claude opencode openclaw nvm npm pnpm rustup uv pipx gh-ext repos flint scribe local-projects brewfile repo-sync shell macos`

### Behavior worth knowing

- **Per-machine config**: `~/.config/alleyuup/config` is symlinked to `alleyuup.conf` in the machine Gist. Any `ALLEYUUP_*` toggle can be set to `0`; lists like `ALLEYUUP_BREW_IGNORE`, `ALLEYUUP_CASK_IGNORE`, `ALLEYUUP_NPM_IGNORE`, and `ALLEYUUP_REPO_IGNORE` skip specific items. Hooks (`alleyuup_before`, `alleyuup_after`) and step overrides (`alleyuup_override_homebrew`, `alleyuup_override_npm`) can be defined there too.
- **Precedence**: defaults < config file < environment < CLI flags.
- **Safety**: a lock prevents overlapping runs; a lock older than `ALLEYUUP_LOCK_MAX_HOURS` (default 6) is reclaimed.
- **Network bounds**: `ALLEYUUP_NET_TIMEOUT` (default 180s) caps each git operation; `ALLEYUUP_NPM_TIMEOUT` (default 900s) caps global npm updates. Optional `ALLEYUUP_MAX_RUNTIME` aborts an entire run.
- **macOS updates**: only same-major updates are installed (`ALLEYUUP_MACOS_MAJOR=1` allows upgrades). Scans are cached for `ALLEYUUP_MACOS_CHECK_HOURS` (default 24).
- **Secrets**: tracked paths are checked against a deny-list (`~/.ssh`, `~/.gnupg`, `gh/hosts.yml`, `opencode/service.json`, …); `dots add` refuses them.
- **Logging**: `ALLEYUUP_LOG=1` (or a path) tees output to `~/Library/Logs/alleyuup.log`, rotated at 5 MB. `ALLEYUUP_NOTIFY=1` posts a macOS notification when a run fails.

## `dots`

```sh
dots link                    # symlink scripts, completions, and configs
dots status                  # symlink health and git status
dots diff                    # uncommitted config changes
dots sync [msg]              # refresh Brewfile, commit, pull --rebase, push
dots pull                    # pull and re-link
dots add <file> [name]       # track a file and link it
dots clean [keep]            # prune stale .bak backups (keeps newest 3)
dots doctor                  # links, completions, repo, PATH, run state, schedule
dots restore [--schedule]    # brew bundle + link (+ weekly job) on a new machine
dots lint                    # bash -n, shellcheck, both test suites
dots schedule install|status|print|remove [hour]
dots repo [target]           # view or change this machine's config repo
dots path                    # print the config repo path
```

Expected doc layout: `bin/`, `completions/`, `tests/`.

## Development

```sh
dots lint        # syntax + shellcheck (if installed) + tests
```

The tests are offline and sandboxed: `tests/test-alleyuup.sh` covers parsers, step filters, lock handling, timeouts, and failure reporting; `tests/test-dots.sh` runs in a throwaway `$HOME` with fake tools/config repos.

## License

MIT — see [LICENSE](LICENSE).
