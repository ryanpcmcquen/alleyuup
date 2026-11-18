#!/usr/bin/env bash
# Tests for dots, run entirely inside a throwaway HOME sandbox.
set -uo pipefail

SRC_DIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

check_exit() {
  local desc="$1" expected="$2" actual="$3"
  check "$desc" "$expected" "$actual"
}

sandbox="$(cd -P "$(mktemp -d "${TMPDIR:-/tmp}/dots-test.XXXXXX")" && pwd)"
trap 'rm -rf "$sandbox"' EXIT

export HOME="$sandbox/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
mkdir -p "$HOME/bin" "$HOME/.config"

# Fake tools repo containing the real scripts
tools="$sandbox/tools"
mkdir -p "$tools"
cp "$SRC_DIR/alleyuup" "$SRC_DIR/dots" "$tools/"
chmod +x "$tools/alleyuup" "$tools/dots"
(
  cd "$tools" || exit 1
  git init -q -b main
  git add -A
  git -c user.email=test@example.com -c user.name=test commit -qm init
)

# Fake machine config repo with two tracked files
repo="$sandbox/repo"
mkdir -p "$repo"
repo="$(cd -P "$repo" && pwd)"
printf '[user]\n\tname = Test\n\temail = test@example.com\n' > "$repo/gitconfig"
printf 'fake zprofile\n' > "$repo/zprofile"
(
  cd "$repo" || exit 1
  git init -q -b main
  git add -A
  git -c user.email=test@example.com -c user.name=test commit -qm init
)

export PATH="$tools:$HOME/bin:$PATH"
export DOTFILES_GIST_DIR="$repo"

DOTS="$tools/dots"

printf 'path\n'
check "dots path prints the machine repo" "$repo" "$("$DOTS" path)"

printf '\nlink\n'
link_out="$("$DOTS" link 2>&1)"
check_contains "links gitconfig" "gitconfig" "$link_out"
if [[ -L "$HOME/.gitconfig" ]]; then
  check "gitconfig symlink target" "$repo/gitconfig" "$(readlink "$HOME/.gitconfig")"
else
  check "gitconfig is a symlink" "yes" "no"
fi
if [[ -L "$HOME/.zprofile" ]]; then
  check "zprofile symlink target" "$repo/zprofile" "$(readlink "$HOME/.zprofile")"
else
  check "zprofile is a symlink" "yes" "no"
fi

printf '\nstatus\n'
status_out="$("$DOTS" status 2>&1)"
check_contains "status shows linked gitconfig" "gitconfig" "$status_out"

printf '\nclean\n'
for i in 1 2 3 4 5; do
  : > "$HOME/.gitconfig.bak.2020010100000$i"
done
clean_out="$("$DOTS" clean 2 2>&1)"
check_contains "clean reports removals" "Removed 3 stale backup(s)" "$clean_out"
remaining="$(find "$HOME" -maxdepth 1 -type f -name '.gitconfig.bak.*' | wc -l | tr -d ' ')"
check "clean keeps newest 2" "2" "$remaining"

printf '\nsensitive paths\n'
mkdir -p "$HOME/.ssh"
: > "$HOME/.ssh/id_rsa"
sensitive_out="$("$DOTS" add "$HOME/.ssh/id_rsa" 2>&1)"
sensitive_status=$?
check_exit "dots add refuses ~/.ssh" "1" "$sensitive_status"
check_contains "dots add explains refusal" "Refusing to track sensitive path" "$sensitive_out"
check "sensitive file was not copied into repo" "0" "$(find "$repo" -maxdepth 1 -name 'id_rsa' | wc -l | tr -d ' ')"

printf '\ndoctor\n'
doctor_out="$("$DOTS" doctor 2>&1)"
check_contains "doctor reads mappings from alleyuup" "read 38 mappings" "$doctor_out"
check_contains "doctor reports no sensitive paths" "no sensitive paths tracked" "$doctor_out"
check_contains "doctor checks the linked configs" "tracked file(s) linked" "$doctor_out"

printf '\nschedule plist\n'
plist_out="$("$DOTS" schedule print 4 2>&1)"
check_contains "plist uses ALLEYUUP_LOG" "<key>ALLEYUUP_LOG</key>" "$plist_out"
check_contains "plist enables notifications" "<key>ALLEYUUP_NOTIFY</key>" "$plist_out"
check_contains "plist uses the requested hour" "<integer>4</integer>" "$plist_out"
check "plist avoids duplicate launchd logging" "0" "$(printf '%s\n' "$plist_out" | grep -c 'StandardOutPath' || true)"

printf '\nsync (push)\n'
git init -q --bare "$sandbox/origin.git"
git -C "$repo" remote add origin "$sandbox/origin.git"
printf 'more\n' >> "$repo/gitconfig"
sync_out="$("$DOTS" sync "test sync" 2>&1)"
sync_status=$?
check_exit "sync exits 0 on success" "0" "$sync_status"
pushed=0
if git -C "$sandbox/origin.git" rev-parse --verify -q main >/dev/null 2>&1; then
  pushed=1
fi
check "sync pushed a commit to origin" "1" "$pushed"

printf '\nsync (push failure)\n'
git -C "$repo" remote set-url origin "$sandbox/missing.git"
printf 'again\n' >> "$repo/gitconfig"
fail_out="$("$DOTS" sync "test fail" 2>&1)"
fail_status=$?
check_exit "failed push exits non-zero" "1" "$fail_status"
check_contains "failed push is reported" "Failed to push machine configs" "$fail_out"

printf '\nversion\n'
check_contains "version prints name" "dots v" "$("$DOTS" --version 2>&1)"

printf '\nhelp\n'
help_out="$("$DOTS" --help 2>&1)"
check_contains "help lists doctor" "doctor" "$help_out"
check_contains "help lists restore" "restore" "$help_out"
check_contains "help lists schedule" "schedule" "$help_out"

printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if (( FAIL > 0 )); then
  exit 1
fi
exit 0
