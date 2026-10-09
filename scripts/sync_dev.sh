#!/usr/bin/env bash
# ==============================================================================
# TOLII App - Automated Developer Sync Script (Bash / macOS / Linux)
# ==============================================================================
# Usage:
#   ./scripts/sync_dev.sh [optional-feature-branch-name]
# ==============================================================================

set -e

BRANCH="${1:-feature/work-$(date +%Y%m%d-%H%M)}"

echo -e "\n🚀 [TOLII] Fetching latest updates from GitHub..."
git fetch origin

if [ -n "$(git status --porcelain)" ]; then
  echo -e "⚠️ [TOLII] Stashing local changes to prevent conflicts..."
  git stash push -m "Auto-stashed by sync_dev.sh on $(date)"
fi

echo -e "🔄 [TOLII] Checking out 'dev' and pulling latest code..."
git checkout dev
git pull origin dev

echo -e "🌿 [TOLII] Creating new feature branch: $BRANCH..."
git checkout -b "$BRANCH"

echo -e "📦 [TOLII] Running flutter pub get..."
flutter pub get

echo -e "\n✅ [TOLII] Ready to build! Work only on $BRANCH and NEVER push directly to dev or main.\n"
