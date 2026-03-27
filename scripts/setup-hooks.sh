#!/usr/bin/env bash
# setup-hooks.sh — Install git hooks for this repo
# Run once after cloning: ./scripts/setup-hooks.sh

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOKS_DIR="$REPO_ROOT/.githooks"
GIT_HOOKS_DIR="$REPO_ROOT/.git/hooks"

echo "⚔️  Installing Order of the Claw git hooks..."

# Configure git to use .githooks directory
git config core.hooksPath ".githooks"

echo "✅ Hooks installed. Pre-push gate is active."
echo ""
echo "  Hooks:"
for hook in "$HOOKS_DIR"/*; do
  echo "    • $(basename $hook)"
done
echo ""
echo "  Requirements: claude CLI must be in PATH"
echo "  Bypass (emergency only): git push --no-verify"
