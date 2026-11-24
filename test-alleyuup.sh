#!/usr/bin/env bash
# Tests for alleyuup helper functions and CLI behavior.
# Runs offline: no Homebrew, npm, or network access required.
set -uo pipefail

SCRIPT_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ALLEYUUP="$SCRIPT_DIR/alleyuup"
PLAIN_CONFIG="/dev/null"
PASS=0
FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    printf '  ok   %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL %s\n' "$desc"
    printf '       expected: %s\n' "$expected"
    printf '       actual:   %s\n' "$actual"
  fi
}

check_contains() {
  local desc="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
    printf '  ok   %s\n' "$desc"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL %s (missing %s)\n' "$desc" "$needle"
  fi
}

# Run a helper from alleyuup in a clean subshell
run_helper() {
  local fixture="$1"
  local expression="$2"
  FIXTURE="$fixture" ALLEYUUP_SOURCE_ONLY=1 ALLEYUUP_CONFIG="$PLAIN_CONFIG" \
    bash -c 'script="$1"; expr="$2"; set --; source "$script" >/dev/null 2>&1 || exit 1; eval "$expr"' _ "$ALLEYUUP" "$expression"
}

printf 'parse_macos_updates\n'
MAC_FIXTURE='Software Update Tool

Finding available software
Software Update found the following new or updated software:
* Label: macOS Sequoia 26.7.4-25G4001
	Title: macOS Sequoia 26.7.4, Version: 26.7.4, Size: 1234KiB, Recommended: YES,

* Label: macOS Tahoe 27.2.1-26B131
	Title: macOS Tahoe 27.2.1, Version: 27.2.1, Size: 2345KiB, Recommended: YES,

* Label: Command Line Tools for Xcode-16.0
	Title: Command Line Tools for Xcode, Version: 16.0, Size: 3456KiB, Recommended: YES,
'
mac_out="$(run_helper "$MAC_FIXTURE" 'printf "%s\n" "$FIXTURE" | parse_macos_updates 26')"
check_contains "installs same-major point release" "INSTALL:macOS Sequoia 26.7.4-25G4001" "$mac_out"
check_contains "skips major OS upgrade" "SKIP:macOS Tahoe 27.2.1-26B131" "$mac_out"
check_contains "installs non-OS updates" "INSTALL:Command Line Tools for Xcode-16.0" "$mac_out"
check "emits one line per update" "3" "$(printf '%s\n' "$mac_out" | grep -c .)"

# With major upgrades allowed everything becomes INSTALL
mac_out_all="$(run_helper "$MAC_FIXTURE" 'printf "%s\n" "$FIXTURE" | parse_macos_updates 0')"
check "major === 0 treats all as INSTALL" "0" "$(printf '%s\n' "$mac_out_all" | grep -c '^SKIP:')"

printf '\nparse_npm_outdated\n'
tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/alleyuup-test.XXXXXX")"
mkdir -p "$tmp_dir/node_modules/alpha" "$tmp_dir/node_modules/beta"
ln -s "$tmp_dir/node_modules/alpha" "$tmp_dir/node_modules/linked"

NPM_FIXTURE="$tmp_dir/node_modules/alpha:alpha@1.0.0:alpha@1.2.0:alpha@1.2.0:global
$tmp_dir/node_modules/beta:beta@2.0.0:beta@2.0.0:beta@2.0.0:global
$tmp_dir/node_modules/linked:linked@1.0.0:linked@3.0.0:linked@3.0.0:global"

npm_out="$(run_helper "$NPM_FIXTURE" 'printf "%s\n" "$FIXTURE" | parse_npm_outdated')"
check "reports outdated package" "alpha" "$npm_out"
check "skips package already at wanted version" "0" "$(printf '%s\n' "$npm_out" | grep -c '^beta$')"
check "skips symlinked local package" "0" "$(printf '%s\n' "$npm_out" | grep -c '^linked$')"

rm -rf "$tmp_dir"

printf '\nCLI: mappings\n'
mappings="$(ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --print-mappings 2>/dev/null)"
check "prints a mapping per tracked file" "38" "$(printf '%s\n' "$mappings" | grep -c .)"
check "every mapping has a separator" "0" "$(printf '%s\n' "$mappings" | grep -vc ':' || true)"
check "tracked filenames are unique" "0" "$(printf '%s\n' "$mappings" | cut -d: -f1 | sort | uniq -d | wc -l | tr -d ' ')"
check_contains "tracks fish config" "config.fish:" "$mappings"
check_contains "tracks alleyuup config" "alleyuup.conf:" "$mappings"

sensitive="$(ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --print-sensitive-patterns 2>/dev/null)"
check_contains "sensitive patterns include ssh" "/.ssh/" "$sensitive"
check_contains "sensitive patterns include gh hosts" "/gh/hosts.yml" "$sensitive"

printf '\nCLI: step filters\n'
steps="$(ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --skip brew,mas --print-steps 2>/dev/null)"
check_contains "--skip disables brew" "ALLEYUUP_BREW=0" "$steps"
check_contains "--skip disables mas" "ALLEYUUP_MAS=0" "$steps"
check_contains "--skip leaves others enabled" "ALLEYUUP_NPM=1" "$steps"

steps="$(ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --skip scribe --print-steps 2>/dev/null)"
check_contains "--skip scribe disables scribe" "ALLEYUUP_SCRIBE=0" "$steps"
check_contains "--skip scribe leaves flint" "ALLEYUUP_FLINT=1" "$steps"

steps="$(ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --skip local-projects --print-steps 2>/dev/null)"
check_contains "--skip local-projects disables flint" "ALLEYUUP_FLINT=0" "$steps"
check_contains "--skip local-projects disables scribe" "ALLEYUUP_SCRIBE=0" "$steps"

steps="$(ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --only flint --print-steps 2>/dev/null)"
check_contains "--only flint enables flint" "ALLEYUUP_FLINT=1" "$steps"
check_contains "--only flint leaves scribe off" "ALLEYUUP_SCRIBE=0" "$steps"

steps="$(ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --only repos --print-steps 2>/dev/null)"
check_contains "--only enables repos" "ALLEYUUP_CODE_REPOS=1" "$steps"
check_contains "--only disables brew" "ALLEYUUP_BREW=0" "$steps"
check_contains "--only disables self-update" "ALLEYUUP_SELF_UPDATE=0" "$steps"

steps="$(ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --dry-run --print-steps 2>/dev/null)"
check_contains "--dry-run sets flag" "ALLEYUUP_DRY_RUN=1" "$steps"

ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --only bogus --print-steps >/dev/null 2>&1
check "unknown --only step exits non-zero" "1" "$?"

printf '\nCLI: environment overrides config\n'
tmp_conf="$(mktemp "${TMPDIR:-/tmp}/alleyuup-conf.XXXXXX")"
printf 'ALLEYUUP_BREW=1\nALLEYUUP_MAS=1\n' > "$tmp_conf"
steps="$(ALLEYUUP_CONFIG="$tmp_conf" ALLEYUUP_BREW=0 ALLEYUUP_MAS=0 "$ALLEYUUP" --print-steps 2>/dev/null)"
check_contains "env disables brew over config" "ALLEYUUP_BREW=0" "$steps"
check_contains "env disables mas over config" "ALLEYUUP_MAS=0" "$steps"
rm -f "$tmp_conf"

printf '\nrotate_log\n'
rot_dir="$(mktemp -d "${TMPDIR:-/tmp}/alleyuup-rot.XXXXXX")"
yes "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789" | head -n 60000 > "$rot_dir/big.log"
rot_lines="$(run_helper "$rot_dir" 'rotate_log "$FIXTURE/big.log"; wc -l < "$FIXTURE/big.log" | tr -d " "')"
check "rotate_log keeps the last 500 lines" "500" "$rot_lines"
rm -rf "$rot_dir"

printf '\nbrew/mas failure reporting\n'
brew_fail_out="$(run_helper "" '
brew() {
  case "$1" in
    update) return 1 ;;
    outdated) return 0 ;;
    upgrade) return 0 ;;
    cleanup) return 0 ;;
  esac
  return 0
}
update_homebrew
echo "rc=$?"
')"
check_contains "brew update failure fails the step" "rc=1" "$brew_fail_out"

brew_ok_out="$(run_helper "" 'brew() { return 0; }; update_homebrew; echo "rc=$?"')"
check_contains "brew success returns 0" "rc=0" "$brew_ok_out"

mas_fail_out="$(run_helper "" 'mas() { return 1; }; update_mas; echo "rc=$?"')"
check_contains "mas outdated failure fails the step" "rc=1" "$mas_fail_out"

mas_ok_out="$(run_helper "" '
mas() {
  case "$1" in
    outdated) printf "123456 App 1.0 -> 1.1\n" ;;
    upgrade) return 0 ;;
  esac
  return 0
}
update_mas
echo "rc=$?"
')"
check_contains "mas success returns 0" "rc=0" "$mas_ok_out"
check_contains "mas lists outdated apps" "App 1.0 -> 1.1" "$mas_ok_out"

mas_sudo_out="$(run_helper "" '
mas() {
  case "$1" in
    outdated) printf "123456 App 1.0 -> 1.1\n" ;;
    upgrade) printf "sudo: a password is required\n"; return 1 ;;
  esac
  return 0
}
update_mas
echo "rc=$?"
' 2>&1)"
check_contains "mas sudo failure is not fatal" "rc=0" "$mas_sudo_out"
check_contains "mas sudo failure explains itself" "need sudo" "$mas_sudo_out"

watchdog_out="$(run_helper "" 'ALLEYUUP_MAX_RUNTIME=0; start_watchdog; [[ -z "$WATCHDOG_PID" ]] && echo "disabled"')"
check_contains "watchdog is disabled when MAX_RUNTIME=0" "disabled" "$watchdog_out"

printf '\nwatchdog does not block the repo step\n'
wd_root="$(mktemp -d "${TMPDIR:-/tmp}/alleyuup-wd.XXXXXX")"
mkdir -p "$wd_root/home/bin" "$wd_root/code/proj/.git" "$wd_root/lock-parent"
cat > "$wd_root/home/bin/git" <<'GIT_STUB'
#!/bin/sh
case "$*" in
  *"remote get-url origin"*) echo "https://example.com/repo.git"; exit 0 ;;
  *" remote"*) echo origin; exit 0 ;;
  *"branch --show-current"*) echo main; exit 0 ;;
  *"rev-parse --short HEAD"*) echo abc1234; exit 0 ;;
  *"rev-list --count"*) echo 1; exit 0 ;;
  *"pull"*) exit 0 ;;
  *"fetch"*) exit 0 ;;
esac
exit 0
GIT_STUB
chmod +x "$wd_root/home/bin/git"
wd_out="$(HOME="$wd_root/home" XDG_CONFIG_HOME="$wd_root/home/.config" \
  ALLEYUUP_CONFIG="$PLAIN_CONFIG" ALLEYUUP_CODE_DIR="$wd_root/code" \
  ALLEYUUP_LOCK_DIR="$wd_root/lock" ALLEYUUP_MAX_RUNTIME=3 \
  "$ALLEYUUP" --only repos 2>&1)"
wd_status=$?
check "repo step completes with a watchdog running" "0" "$wd_status"
check "watchdog did not fire" "0" "$(printf '%s\n' "$wd_out" | grep -c 'exceeded ALLEYUUP_MAX_RUNTIME' || true)"
rm -rf "$wd_root"

printf '\nrun_with_timeout\n'
t_start="$(date +%s)"
run_helper "" 'run_with_timeout 1 sleep 5' >/dev/null 2>&1
t_status=$?
t_elapsed=$(( $(date +%s) - t_start ))
check "timeout aborts a slow command" "yes" "$([[ $t_status -ne 0 ]] && echo yes || echo no)"
check "timeout returns promptly" "yes" "$([[ $t_elapsed -le 3 ]] && echo yes || echo no)"

printf '\nrun lock\n'
lock_root="$(mktemp -d "${TMPDIR:-/tmp}/alleyuup-lock.XXXXXX")"
lock_dir="$lock_root/lock"
mkdir -p "$lock_dir"
printf '%s\n' "$$" > "$lock_dir/pid"
date +%s > "$lock_dir/started"
active_out="$(ALLEYUUP_LOCK_DIR="$lock_dir" ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --only self-update --dry-run 2>&1)"
active_status=$?
check "active lock skips the run" "0" "$active_status"
check_contains "active lock is reported" "already running" "$active_out"
check "active lock is preserved" "yes" "$([[ -d "$lock_dir" ]] && echo yes || echo no)"

printf '%s\n' "$(( $(date +%s) - 8 * 3600 ))" > "$lock_dir/started"
stale_out="$(ALLEYUUP_LOCK_DIR="$lock_dir" ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --only self-update --dry-run 2>&1)"
stale_status=$?
check "stale lock is taken over" "0" "$stale_status"
check_contains "stale lock is reported" "Stale lock" "$stale_out"
check "lock is released after the run" "no" "$([[ -d "$lock_dir" ]] && echo yes || echo no)"
rm -rf "$lock_root"

printf '\nCLI: init-config\n'
init_conf="$(mktemp "${TMPDIR:-/tmp}/alleyuup-init.XXXXXX")"
rm -f "$init_conf"
ALLEYUUP_CONFIG="$init_conf" "$ALLEYUUP" --init-config >/dev/null 2>&1
check "init-config creates the file" "yes" "$([[ -f "$init_conf" ]] && echo yes || echo no)"
check_contains "init-config writes defaults" "ALLEYUUP_BREW=1" "$(cat "$init_conf" 2>/dev/null)"
init_again="$(ALLEYUUP_CONFIG="$init_conf" "$ALLEYUUP" --init-config 2>&1)"
check_contains "init-config does not overwrite" "already exists" "$init_again"
rm -f "$init_conf"

printf '\nCLI: help and version\n'
help_out="$(ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --help 2>/dev/null)"
check_contains "--help lists --dry-run" "--dry-run" "$help_out"
check_contains "--help lists --only" "--only <steps>" "$help_out"
check_contains "--help lists step keys" "repo-sync" "$help_out"

version_out="$(ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --version 2>/dev/null)"
check_contains "--version prints name" "alleyuup v" "$version_out"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if (( FAIL > 0 )); then
  exit 1
fi
exit 0
