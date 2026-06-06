# Project: Claude Sandbox

## Context

A credential-isolated Docker sandbox for running Claude Code. The sandbox mounts
the current working directory read/write but keeps host credentials (`~/.aws`,
`~/.ssh`, etc.) invisible. Useful when running claude on projects where you don't
want it to have accidental access to cloud credentials or SSH keys.

## Files

- `Dockerfile` — Debian bookworm-slim image with claude, node 24, uv + python 3.12,
  gh, git, neovim (stable), ripgrep, fd, jq
- `claude-sandbox.sh` — shell functions to source from `.zshrc`

## Setup

### Prerequisites

- Docker running
- 1Password CLI installed and signed in (`op signin`)
- GitHub read-only token at `op://Private/github.com/READ_ONLY_GITHUB_TOKEN`

### Wire up

Add to `.zshrc`:
```zsh
source /path/to/claude_sandbox/claude-sandbox.sh
```

### Build the image

```bash
claude-sandbox-build
```

Your UID/GID are baked in at build time so files created in the sandbox are owned
correctly on the host. The image auto-rebuilds if it is more than 24 hours old when
you run `claude-sandbox`.

Override versions for a one-off build:
```bash
PYTHON_VERSION=3.11 NODE_VERSION=22 claude-sandbox-build
```

## Commands

```bash
claude-sandbox              # start claude in the current directory
claude-sandbox-shell        # open a bash shell in the sandbox
claude-sandbox-shell -c "…" # run a single command and exit
claude-sandbox-build        # build or rebuild the image
```

## What Is and Isn't Available

| Resource | Available | Notes |
|---|---|---|
| Current directory | Yes, read/write | Mounted at `/workspace` |
| `~/.claude/` | Yes, read/write | Credentials, history, memory |
| `~/.claude.json` | Yes, read/write | Claude config file (separate from the directory) |
| `~/.gitconfig` | Yes, read-only | Git identity |
| `~/.config/nvim` | Yes, read-only | LazyVim config |
| `~/.local/share/nvim` | Yes, read/write | LazyVim plugins |
| `~/.local/state/nvim` | Yes, read/write | Undo history, shada |
| `~/.local/cache/nvim` | Yes, read/write | TreeSitter parsers |
| `~/.ssh/signing_key{,.pub}` | Yes, read-only | Only if present; matches `user.signingkey` in `gitconfig.core`. Signing only, not auth. |
| `GH_TOKEN` | Yes | Read-only token from 1Password at startup |
| `~/.aws` | **No** | |
| `~/.ssh` (agent/keys) | **No** | |
| `~/.netrc`, `~/.config/gcloud` | **No** | |
| Other host env vars | **No** | |

## Design Notes

**`--network host`** — required. Docker's bridge NAT breaks claude's OAuth token
validation. Credential isolation is filesystem-level (mounts), not network-level,
so this doesn't compromise the isolation goal.

**UID/GID baked at build time** — `claude-sandbox-build` passes `$(id -u)` and
`$(id -g)` as build args so the `sandbox` user inside the container has the same
numeric ID as the host user. Files created in the sandbox are owned correctly on
the host without needing `chown`.

**`~/.claude.json` is separate from `~/.claude/`** — claude requires both. The
directory holds credentials, history, and memory; the JSON file holds configuration.
Both need to be explicitly mounted.

**Python** — no system `python` or `python3` symlink. Use `uv venv --python 3.12`
to create project venvs. The python managed by uv is at `UV_PYTHON_INSTALL_DIR=/opt/uv-python`.

**SSH signing without push** — mount `~/.ssh/signing_key` (and `.pub`) read-only at
the same path inside the container so the `user.signingkey = ~/.ssh/signing_key.pub`
entry in `gitconfig.core` resolves correctly on both sides. Register the key on
GitHub as a *Signing Key* (not Authentication Key) so it can sign commits locally
but cannot authenticate SSH transport — `git push` over SSH stays blocked.

## Status

Working as of 2026-06-06. Tested on Linux with Docker 29.5.2.
