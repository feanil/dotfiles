#!/usr/bin/env bash
# claude-sandbox-statusline — statusline for the credential-isolated sandbox.
#
# Wired up at launch via --settings in claude-sandbox.sh (NOT in the shared
# ~/.claude/settings.json), so the badge only ever shows inside the sandbox.
#
# Claude Code feeds this command the status JSON on stdin; we print a one-line
# status led by a prominent SANDBOX badge so it's obvious this is the nested
# sandbox Claude rather than the host Claude.
input=$(cat)
model=$(printf '%s' "$input" | jq -r '.model.display_name // "claude"')
dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // ""')

# Black text on a yellow background for the badge, then bold model + dim path.
printf '\033[30;43m 🧪 SANDBOX \033[0m \033[1m%s\033[0m \033[2m%s\033[0m' "$model" "$dir"
