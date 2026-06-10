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
- `statusline.sh` — baked into the image as `claude-sandbox-statusline`; renders the
  `🧪 SANDBOX` badge. Referenced from the sandbox settings profile (see below),
  never from the host's `settings.json`.

## Setup

### Prerequisites

- Docker running
- 1Password CLI installed and signed in (`op signin`)
- GitHub read-only token at `op://Private/github.com/READ_ONLY_GITHUB_TOKEN`

### Wire up

Add to `.zshrc`:
```zsh
source /path/to/dotfiles/config/shellrc/claude_sandbox/claude-sandbox.sh
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
claude-sandbox                  # start claude in the current directory
claude-sandbox-run bash         # open a bash shell in the sandbox
claude-sandbox-run bash -c "…"  # run a single command and exit
claude-sandbox-build            # build or rebuild the image
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

## Telling You're in the Sandbox

The sandbox runs Claude *inside* Claude, so it's easy to lose track of which one
you're in. Three cues make it obvious, all driven off the `CLAUDE_SANDBOX=1` env
var set on the container:

- **Statusline badge** — a `🧪 SANDBOX` badge (black on yellow) plus model and
  cwd. Rendered by `claude-sandbox-statusline` (baked into the image) and declared
  in the sandbox settings profile (`.claude/settings.sandbox.json`), which
  `claude-sandbox` loads at launch via `claude --settings`. The host Claude never
  loads that profile, so it never shows the badge.
- **System-prompt note** — `claude-sandbox` passes `--append-system-prompt` with a
  short note telling Claude it's sandboxed and what is / isn't available, so Claude
  itself can tell. Sandbox-only; nothing is written to the shared `~/.claude/CLAUDE.md`.
- **`CLAUDE_SANDBOX=1`** — available to any script or agent that wants to detect the
  sandbox.

`~/.claude/settings.json` and `~/.claude/CLAUDE.md` are mounted read/write from the
host, so neither cue is configured there — that would leak onto the host Claude. The
badge lives in the sandbox-only profile and the note is layered on via a CLI flag.

## Sandbox permissions (isolating sandbox grants from privileged Claude)

The point of the sandbox is to run Claude with broad permissions you'd never want
it to have in general, un-sandboxed use. The credential isolation is the real safety
boundary; the permission system just controls prompting. The mechanism for keeping
sandbox grants out of the host:

- **`.claude/settings.sandbox.json`** — the sandbox settings profile, loaded only
  inside the sandbox via `claude --settings <file>`. `claude-sandbox` seeds it on
  first use with the statusline badge and `permissions.defaultMode: "acceptEdits"`;
  add whatever broad `permissions.allow` rules you want here. Host Claude never loads
  this file (it isn't one of Claude's standard settings sources: user
  `~/.claude/settings.json`, project `.claude/settings.json`, local
  `.claude/settings.local.json`), so anything you put here is walled off from
  privileged Claude. Permission arrays *merge* across sources, so the profile's
  `allow` rules are additive on top of whatever the standard sources grant.
- Sharing one profile across concurrent sandbox runs is fine — the boundary we care
  about is host vs. sandbox, not sandbox vs. sandbox.
- **Known gap:** an interactively-"remembered" permission ("yes, don't ask again")
  persists to `.claude/settings.local.json`, which is host-shared through the
  `/workspace` mount — so it *can* reach privileged Claude. Mitigation: keep the
  permissions you want broadly in the profile so the sandbox rarely has to prompt.
  `--setting-sources user,project` (dropping `local`) would stop the sandbox from
  even loading that file, but where remembered rules then get written is undocumented
  — verify before relying on it.

Gitignore in the projects you run the sandbox against: `.claude/settings.local.json`
is throwaway machine-local state and should always be ignored. `.claude/settings.sandbox.json`
is the profile you curate — ignore it if it's personal, or commit it to share a sandbox
permission profile with the team. A global `~/.config/git/ignore` entry covers every
repo at once for the local file.

## 1Password prompt

Before reading the GitHub token, `claude-sandbox` prints why it's about to call
`op read`, so the 1Password authorization prompt (biometric/system auth) isn't a
mystery.

## Privileged action handoff

The sandbox can *do* work but lacks the credentials to push, open PRs, deploy, etc.
When claude hits such an action it doesn't improvise around it — it follows a handoff
protocol baked into the injected system-prompt note (`--append-system-prompt` in
`claude-sandbox`):

- **Artifact handoff** — claude finishes everything it can locally and commits to a
  branch (or writes a patch), so the privileged step only has to *transmit* the
  result, never re-derive it. This keeps execution close to the moment with the most
  context, and shrinks the privileged surface to pure transmission.
- **Structured queue** — the residual privileged steps are appended to `PRIVILEGED.md`
  in `/workspace` (host-visible) as concrete, paste-ready commands, one status-tracked
  block per action:

  ```markdown
  ## [ ] Push branch and open PR for the auth refactor
  - **Why:** sandbox GH_TOKEN is read-only; push + PR creation need write access.
  - **cwd:** `/workspace`
  - **Artifact:** local branch `auth-refactor` (commits already made in the sandbox)
  - **Run:**
    ```bash
    git push -u origin auth-refactor
    gh pr create --draft --fill
    ```
  ```

You then consume the queue from a **monitored privileged session** — a normal
(non-sandboxed) claude or shell with full credentials — reviewing each block, running
it, and changing `[ ]` to `[x]`. The queue is never auto-executed: review is the
safeguard, since a confused or injected sandbox claude could otherwise queue something
unwanted.

This is advisory (system-prompt driven), not enforced. A `PreToolUse` hook could *make*
claude follow it and capture the exact command verbatim, but that adds a brittle
pattern list and gates every Bash call, so it's deliberately left out for now.

`PRIVILEGED.md` is transient handoff state, not project content — consider gitignoring
it in the projects you run the sandbox against.

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
