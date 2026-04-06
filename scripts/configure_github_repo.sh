#!/usr/bin/env bash

set -euo pipefail

REPO_SLUG="${REPO_SLUG:-}"
TARGET_REPO_URL="${TARGET_REPO_URL:-https://github.com/EGgames/HOTEL-MVP.git}"
TARGET_REPO_BRANCH="${TARGET_REPO_BRANCH:-dev}"
QA_DB_PORT="${QA_DB_PORT:-5540}"
QA_API_PORT="${QA_API_PORT:-3100}"
DB_QA_FAILURE_ISSUES_ENABLED="${DB_QA_FAILURE_ISSUES_ENABLED:-true}"

if [[ -z "$REPO_SLUG" ]]; then
  origin_url="$(git remote get-url origin)"
  REPO_SLUG="${origin_url#https://github.com/}"
  REPO_SLUG="${REPO_SLUG%.git}"
fi

gh variable set DB_QA_TARGET_REPO_URL --repo "$REPO_SLUG" --body "$TARGET_REPO_URL"
gh variable set DB_QA_TARGET_REPO_BRANCH --repo "$REPO_SLUG" --body "$TARGET_REPO_BRANCH"
gh variable set DB_QA_DB_PORT --repo "$REPO_SLUG" --body "$QA_DB_PORT"
gh variable set DB_QA_API_PORT --repo "$REPO_SLUG" --body "$QA_API_PORT"
gh variable set DB_QA_FAILURE_ISSUES_ENABLED --repo "$REPO_SLUG" --body "$DB_QA_FAILURE_ISSUES_ENABLED"

printf 'Configured variables for %s\n' "$REPO_SLUG"
