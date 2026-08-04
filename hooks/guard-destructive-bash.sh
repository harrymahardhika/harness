#!/usr/bin/env bash
# PreToolUse hook for the Bash tool. Reads the hook JSON payload on stdin,
# inspects tool_input.command, and forces a human approval prompt (rather
# than a silent block) for commands that are hard to reverse.
#
# Requires `jq`. Wired up via hooks/settings.json's PreToolUse entry.
#
# Blocked-until-approved patterns:
#   - rm -rf (and -fr / -r -f variants)
#   - `migrate:fresh` / `migrate:reset` / `db:wipe` when the invoking
#     project's .env has APP_ENV set to anything other than local/testing
#     (or has no .env at all, which we treat as "unknown => not local").

set -euo pipefail

payload="$(cat)"
command="$(jq -r '.tool_input.command // empty' <<<"$payload")"

if [[ -z "$command" ]]; then
  exit 0
fi

deny() {
  local reason="$1"
  jq -n --arg reason "$reason" \
    '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "ask", permissionDecisionReason: $reason}}'
  exit 0
}

# --- rm -rf (any argument order: -rf, -fr, -r -f, --recursive --force) ---
if grep -qE '\brm\b[^|;&]*(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*|--recursive[^|;&]*--force|--force[^|;&]*--recursive)' <<<"$command"; then
  deny "Blocked: '$command' looks like a recursive force-delete (rm -rf). Confirm with the user before running."
fi

# --- migrate:fresh / migrate:reset / db:wipe on a non-local environment ---
if grep -qE '\b(artisan\s+migrate:(fresh|reset)|artisan\s+db:wipe)\b' <<<"$command"; then
  # Find the nearest .env by walking up from CWD, falling back to
  # CLAUDE_PROJECT_DIR if set.
  search_dir="${PWD}"
  env_file=""
  while [[ "$search_dir" != "/" ]]; do
    if [[ -f "$search_dir/.env" ]]; then
      env_file="$search_dir/.env"
      break
    fi
    search_dir="$(dirname "$search_dir")"
  done
  if [[ -z "$env_file" && -n "${CLAUDE_PROJECT_DIR:-}" && -f "${CLAUDE_PROJECT_DIR}/.env" ]]; then
    env_file="${CLAUDE_PROJECT_DIR}/.env"
  fi

  app_env=""
  if [[ -n "$env_file" ]]; then
    app_env="$(grep -E '^APP_ENV=' "$env_file" | head -n1 | cut -d= -f2- | tr -d '"'"'"' \r')"
  fi

  if [[ "$app_env" != "local" && "$app_env" != "testing" ]]; then
    deny "Blocked: '$command' targets APP_ENV='${app_env:-<unknown, no .env found>}', not local/testing. Confirm with the user before running a destructive migration."
  fi
fi

exit 0
