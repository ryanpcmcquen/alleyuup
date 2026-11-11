#!/usr/bin/env bash
set -euo pipefail

TOOLS_GIST_ID="alleyuup-repo"
TOOLS_DIR="${ALLEYUP_TOOLS_DIR:-$HOME/code/$TOOLS_GIST_ID}"
BIN_DIR="${ALLEYUP_BIN_DIR:-$HOME/bin}"

BOLD="\033[1m"
BLUE="\033[1;34m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
RESET="\033[0m"

printf "${BLUE}==> Installing alleyup & dots...${RESET}\n"
mkdir -p "$HOME/code" "$BIN_DIR"

if [[ -d "$TOOLS_DIR/.git" ]]; then
  printf "Updating existing tools clone in %s...\n" "$TOOLS_DIR"
  git -C "$TOOLS_DIR" pull --rebase origin main
else
  printf "Cloning tools Gist into %s...\n" "$TOOLS_DIR"
  if ! git clone "https://gist.github.com/${TOOLS_GIST_ID}.git" "$TOOLS_DIR" 2>/dev/null; then
    git clone "git@gist.github.com:${TOOLS_GIST_ID}.git" "$TOOLS_DIR"
  fi
  # Switch remote to SSH if the user has SSH configured for GitHub
  if ssh -o BatchMode=yes -o ConnectTimeout=3 -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    git -C "$TOOLS_DIR" remote set-url origin "git@gist.github.com:${TOOLS_GIST_ID}.git"
  fi
fi

chmod +x "$TOOLS_DIR/alleyup" "$TOOLS_DIR/dots"
ln -sfn "$TOOLS_DIR/alleyup" "$BIN_DIR/alleyup"
ln -sfn "$TOOLS_DIR/dots" "$BIN_DIR/dots"

printf "${GREEN}✓ Linked:${RESET} %s/alleyup -> %s/alleyup\n" "$BIN_DIR" "$TOOLS_DIR"
printf "${GREEN}✓ Linked:${RESET} %s/dots    -> %s/dots\n" "$BIN_DIR" "$TOOLS_DIR"

if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
  printf "\n${YELLOW}Note:${RESET} %s is not in your current PATH yet.\n" "$BIN_DIR"
  printf "Run '${BOLD}%s/dots link${RESET}' to link your shell configs, or add %s to your PATH.\n" "$BIN_DIR" "$BIN_DIR"
fi

printf "\n${BOLD}${GREEN}✨ Installed!${RESET} Run '${BOLD}alleyup${RESET}' to upgrade, or '${BOLD}dots repo${RESET}' to connect this machine's config Gist.\n"
