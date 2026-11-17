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

printf '\nCLI: step filters\n'
steps="$(ALLEYUUP_CONFIG="$PLAIN_CONFIG" "$ALLEYUUP" --skip brew,mas --print-steps 2>/dev/null)"
check_contains "--skip disables brew" "ALLEYUUP_BREW=0" "$steps"
check_contains "--skip disables mas" "ALLEYUUP_MAS=0" "$steps"
check_contains "--skip leaves others enabled" "ALLEYUUP_NPM=1" "$steps"

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
