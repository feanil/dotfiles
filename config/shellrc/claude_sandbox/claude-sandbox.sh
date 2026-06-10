#!/usr/bin/env bash
# claude-sandbox.sh — credential-isolated Claude Code sandbox
#
# Prerequisites:
#   - Docker running (docker info)
#   - 1Password CLI installed and signed in (op signin)
#   - GitHub read-only token stored in 1Password at:
#       op://Private/github.com/READ_ONLY_GITHUB_TOKEN
#   - Image built at least once: claude-sandbox-build
#
# Source from .zshrc:
#   source /path/to/dotfiles/config/shellrc/claude_sandbox/claude-sandbox.sh
#
# Commands this provides:
#   claude-sandbox        — run claude in the sandbox from the current directory
#   claude-sandbox-run    — run an arbitrary command in the sandbox
#                           (e.g. `claude-sandbox-run bash` for a shell)
#   claude-sandbox-build  — build (or rebuild) the sandbox image

# Exported so Claude Code's shell snapshot (which preserves env vars and
# non-`_`-prefixed functions, but not bare top-level assignments) keeps them
# available when these helpers run in a non-interactive subshell.
export CLAUDE_SANDBOX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
export CLAUDE_SANDBOX_IMAGE="claude-sandbox:latest"

# Build or rebuild the sandbox image.
# Your UID/GID are baked in at build time so file ownership matches the host.
#
# Override versions for a one-off build:
#   PYTHON_VERSION=3.11 NODE_VERSION=22 claude-sandbox-build
claude-sandbox-build() {
    docker build \
        --no-cache \
        --pull \
        --build-arg PYTHON_VERSION="${PYTHON_VERSION:-3.12}" \
        --build-arg NODE_VERSION="${NODE_VERSION:-24}" \
        --build-arg SANDBOX_UID="$(id -u)" \
        --build-arg SANDBOX_GID="$(id -g)" \
        -f "$CLAUDE_SANDBOX_DIR/Dockerfile" \
        -t "$CLAUDE_SANDBOX_IMAGE" \
        "$CLAUDE_SANDBOX_DIR"
}

# Run claude in a credential-isolated sandbox with the current directory mounted.
#
# What is NOT available inside the sandbox:
#   ~/.aws, ~/.ssh (agent + keys), host env vars, ~/.netrc, ~/.config/gcloud, etc.
#
# What IS available:
#   /workspace            — current directory, read/write
#   ~/.claude             — claude login, config, and history (read/write)
#   ~/.claude.json        — claude configuration file (read/write)
#   ~/.gitconfig          — read-only
#   ~/.config/nvim        — read-only (LazyVim config)
#   ~/.local/share/nvim   — read/write (LazyVim plugins, persisted on host)
#   ~/.local/state/nvim   — read/write (undo history, shada)
#   ~/.local/cache/nvim   — read/write (TreeSitter parsers, etc.)
#   ~/.ssh/signing_key{,.pub} — read-only, if present (for commit signing only)
#
# Any extra arguments are forwarded to claude:
#   claude-sandbox "fix the tests"
# Shared setup and docker run — takes the container command as arguments.
# Named without a `_` prefix so Claude Code's shell snapshot preserves it
# (it strips `_`-prefixed functions when capturing the interactive shell).
claude-sandbox-run() {
    local -a extra_flags=()

    if [[ -f "$HOME/.ssh/signing_key" ]]; then
        extra_flags+=(
            -v "$HOME/.ssh/signing_key:/home/sandbox/.ssh/signing_key:ro"
            -v "$HOME/.ssh/signing_key.pub:/home/sandbox/.ssh/signing_key.pub:ro"
        )
    fi

    if ! docker image inspect "$CLAUDE_SANDBOX_IMAGE" &>/dev/null; then
        echo "claude-sandbox: error: image '$CLAUDE_SANDBOX_IMAGE' not found — run claude-sandbox-build first" >&2
        return 1
    fi

    local created created_epoch now_epoch
    created=$(docker image inspect "$CLAUDE_SANDBOX_IMAGE" --format '{{.Created}}')
    created_epoch=$(date -d "$created" +%s)
    now_epoch=$(date +%s)
    if (( now_epoch - created_epoch > 86400 )); then
        echo "claude-sandbox: image is more than 24h old, rebuilding..." >&2
        claude-sandbox-build || return 1
    fi

    # op read may trigger a 1Password authorization prompt (biometric/system
    # auth). Explain why before it appears so it isn't a mystery prompt.
    echo "claude-sandbox: reading the read-only GitHub token from 1Password" >&2
    echo "  (op://Private/github.com/READ_ONLY_GITHUB_TOKEN) to pass into the sandbox as GH_TOKEN." >&2
    echo "  1Password may prompt you to authorize access." >&2

    local gh_token
    if ! gh_token=$(op read "op://Private/github.com/READ_ONLY_GITHUB_TOKEN" 2>/dev/null); then
        echo "claude-sandbox: error: could not read GitHub token from 1Password (is op signed in?)" >&2
        return 1
    fi
    extra_flags+=(-e "GH_TOKEN=$gh_token")

    # Resolve git identity on the host (where includeIf works) and pass the
    # values in directly — the container can't follow the relative include paths
    # because its $HOME differs from the host's.
    local git_name git_email
    git_name=$(git config user.name 2>/dev/null)
    git_email=$(git config user.email 2>/dev/null)
    [[ -n "$git_name" ]]  && extra_flags+=(-e "GIT_AUTHOR_NAME=$git_name"    -e "GIT_COMMITTER_NAME=$git_name")
    [[ -n "$git_email" ]] && extra_flags+=(-e "GIT_AUTHOR_EMAIL=$git_email"  -e "GIT_COMMITTER_EMAIL=$git_email")

    docker run -it --rm \
        `# Docker's bridge NAT breaks claude's OAuth token validation.` \
        --network host \
        -e HOME=/home/sandbox \
        `# Marks the environment as the sandbox — drives the statusline badge.` \
        -e CLAUDE_SANDBOX=1 \
        `# TERM is hardcoded rather than forwarded: Debian's base ncurses only` \
        `# ships terminfo for a small set of TERM values (xterm-256color is in,` \
        `# tmux-256color is not), so forwarding TERM=tmux-256color from a host` \
        `# shell inside tmux would degrade ncurses programs in the container.` \
        `# Truecolor is advertised separately via COLORTERM.` \
        -e TERM=xterm-256color \
        -e "COLORTERM=${COLORTERM:-truecolor}" \
        -v "$PWD:/workspace" \
        -w /workspace \
        -v "$HOME/.claude:/home/sandbox/.claude" \
        -v "$HOME/.claude.json:/home/sandbox/.claude.json" \
        -v "$HOME/.gitconfig:/home/sandbox/.gitconfig:ro" \
        -v "$HOME/.config/nvim:/home/sandbox/.config/nvim:ro" \
        -v "$HOME/.local/share/nvim:/home/sandbox/.local/share/nvim" \
        -v "$HOME/.local/state/nvim:/home/sandbox/.local/state/nvim" \
        -v "$HOME/.local/cache/nvim:/home/sandbox/.local/cache/nvim" \
        "${extra_flags[@]}" \
        "$CLAUDE_SANDBOX_IMAGE" \
        "$@"
}

# Run claude in the sandbox from the current directory.
# Any extra arguments are forwarded to claude: claude-sandbox "fix the tests"
#
# Two sandbox cues are layered on at launch:
#   --settings              points claude at the sandbox profile (statusline badge
#                           so *you* can tell at a glance, plus sandbox-only perms).
#   --append-system-prompt  tells *claude* it's sandboxed and what is / isn't there.
claude-sandbox() {
    local sandbox_note
    sandbox_note=$(cat <<'EOF'
You are running inside "claude-sandbox", a credential-isolated Docker container,
not on the host machine.

Available: the current directory at /workspace (read/write); your ~/.claude config
and history; ~/.gitconfig and git identity; an SSH signing key (commit signing only,
if present); and GH_TOKEN, a READ-ONLY GitHub token.

Not available (do not try to use these): ~/.aws, SSH auth keys and the SSH agent,
~/.config/gcloud, ~/.netrc, and host environment variables. Because GH_TOKEN is
read-only and SSH auth is blocked, gh/git operations that write to GitHub (push,
PR edits, etc.) will fail.

When a task needs an action you cannot perform here (anything requiring those
missing credentials — git push, gh PR create/merge/edit, AWS, gcloud, terraform
apply, deploys, sudo), do NOT attempt it and do NOT work around it. Instead:
  1. Finish everything you CAN do locally first, and leave a ready-to-ship
     artifact: commit your work to a local branch (or write a patch) so the
     privileged step only has to transmit it, not redo it.
  2. Append a concrete, reviewable entry to ./PRIVILEGED.md (create it if missing;
     it lives in /workspace and is consumed later by a separate monitored
     privileged session). One block per action, newest at the bottom, in this
     exact format:

       ## [ ] <short title>
       - **Why:** <one line: why it needs privilege>
       - **cwd:** `<dir>`
       - **Artifact:** <local branch / patch file, or "none">
       - **Run:**
         ```bash
         <exact, paste-ready command(s)>
         ```

     Log exact commands, never prose — the privileged session reviews and runs
     them as-is, then changes [ ] to [x]. Group an artifact and the command that
     ships it into one entry (e.g. commit to a branch, then `git push` + PR).
  3. In your final summary, tell the user you queued actions in PRIVILEGED.md.

Mention this sandbox context when it's relevant to what the user asks.
EOF
)

    # Sandbox settings profile, loaded only inside the sandbox via --settings.
    # It carries the statusline badge and any permissions you're willing to grant
    # in the credential-isolated sandbox but NOT to general, un-sandboxed claude.
    # Host claude never loads this file (it isn't one of claude's standard settings
    # sources), so anything you put here stays walled off from privileged claude —
    # which is the only isolation boundary we actually care about. Sharing one file
    # across concurrent sandbox runs is fine; we're not isolating sandboxes from
    # each other.
    #
    # Caveat: claude persists interactively-"remembered" permissions to
    # .claude/settings.local.json, which is host-shared through the /workspace
    # mount — so a "yes, don't ask again" click inside the sandbox CAN reach
    # privileged claude. Keep the perms you want broadly in this profile so the
    # sandbox rarely has to prompt, and that path stays closed.
    local sandbox_settings=".claude/settings.sandbox.json"

    # Seed a default profile on first use: the statusline badge plus acceptEdits so
    # file edits don't prompt. Add your broad sandbox-only permissions here.
    mkdir -p .claude
    if [[ ! -f "$sandbox_settings" ]]; then
        cat > "$sandbox_settings" <<'JSON'
{
  "statusLine": { "type": "command", "command": "claude-sandbox-statusline" },
  "permissions": {
    "defaultMode": "acceptEdits",
    "allow": []
  }
}
JSON
    fi

    claude-sandbox-run claude \
        --settings "$sandbox_settings" \
        --append-system-prompt "$sandbox_note" \
        "$@"
}

