#!/usr/bin/env bash
# Derives a Snowflake-safe schema name from a branch name.
#
# Rule: take the first two "-"-separated tokens (e.g. JIRA-123-add-a-column
# -> JIRA_123). If the branch name has fewer than two tokens, fall back to
# the whole branch name, sanitized.
#
# Usage: scripts/derive_schema_name.sh <branch-name>

set -euo pipefail

branch="${1:?usage: derive_schema_name.sh <branch-name>}"

sanitize() {
  printf '%s' "$1" | tr -c 'A-Za-z0-9' '_' | tr 'a-z' 'A-Z' | sed -E 's/_+/_/g; s/^_//; s/_$//'
}

IFS='-' read -ra tokens <<< "$branch"

if [ "${#tokens[@]}" -ge 2 ]; then
  echo "$(sanitize "${tokens[0]}")_$(sanitize "${tokens[1]}")"
else
  sanitize "$branch"
fi
